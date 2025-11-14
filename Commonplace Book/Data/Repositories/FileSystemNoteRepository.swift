// ABOUTME: File system-based note repository with atomic writes and in-memory caching
// ABOUTME: Thread-safe actor that persists notes as markdown files with YAML frontmatter

import Foundation

/// File system note repository with atomic writes and caching
actor FileSystemNoteRepository: NoteRepository {

    private let directory: URL
    private let formatter: NoteFileFormatter
    private let fileManager: FileManager
    #if os(macOS)
    private var gitSyncService: GitSyncService?
    #elseif os(iOS)
    private var gitSyncService: GitSyncServiceiOS?
    #endif

    // In-memory cache for performance
    private var cache: [UUID: Note] = [:]

    // Cache loading state to prevent concurrent loads
    private enum CacheState {
        case notLoaded
        case loading(Task<Void, Error>)
        case loaded
    }
    private var cacheState: CacheState = .notLoaded

    #if os(macOS)
    init(directory: URL, gitSyncService: GitSyncService? = nil) {
        self.directory = directory
        self.formatter = NoteFileFormatter()
        self.fileManager = FileManager.default
        self.gitSyncService = gitSyncService
    }

    /// Set or update the git sync service
    func setGitSyncService(_ service: GitSyncService?) {
        self.gitSyncService = service
    }
    #elseif os(iOS)
    init(directory: URL, gitSyncService: GitSyncServiceiOS? = nil) {
        self.directory = directory
        self.formatter = NoteFileFormatter()
        self.fileManager = FileManager.default
        self.gitSyncService = gitSyncService
    }

    /// Set or update the git sync service
    func setGitSyncService(_ service: GitSyncServiceiOS?) {
        self.gitSyncService = service
    }
    #else
    init(directory: URL) {
        self.directory = directory
        self.formatter = NoteFileFormatter()
        self.fileManager = FileManager.default
    }
    #endif

    // MARK: - NoteRepository Protocol

    func create(note: Note) async throws -> Note {
        // Ensure directory exists
        try ensureDirectoryExists()

        // Load cache if needed
        try await loadCacheIfNeeded()

        // Check for duplicate
        if cache[note.id] != nil {
            throw RepositoryError.duplicateNote(note.id)
        }

        // Write to disk atomically
        try await writeNoteToDisk(note: note)

        // Update cache
        cache[note.id] = note

        // Trigger git commit if git sync is enabled
        #if os(macOS) || os(iOS)
        if let gitSync = gitSyncService {
            await gitSync.commitNoteChange(noteID: note.id, action: .add, title: note.title)
        }
        #endif

        return note
    }

    func read(id: UUID) async throws -> Note? {
        // Load cache if needed
        try await loadCacheIfNeeded()

        // Return from cache if available
        if let cachedNote = cache[id] {
            return cachedNote
        }

        // Try to read from disk (in case file was added externally)
        let filePath = noteFilePath(for: id)
        guard fileManager.fileExists(atPath: filePath.path) else {
            return nil
        }

        do {
            let note = try await readNoteFromDisk(id: id)
            cache[id] = note
            return note
        } catch {
            // File exists but is corrupt - throw the error
            throw error
        }
    }

    func update(note: Note) async throws -> Note {
        // Ensure directory exists
        try ensureDirectoryExists()

        // Load cache if needed
        try await loadCacheIfNeeded()

        // Check note exists
        guard cache[note.id] != nil else {
            throw RepositoryError.noteNotFound(note.id)
        }

        // Write to disk atomically
        try await writeNoteToDisk(note: note)

        // Update cache
        cache[note.id] = note

        // Trigger git commit if git sync is enabled
        #if os(macOS) || os(iOS)
        if let gitSync = gitSyncService {
            await gitSync.commitNoteChange(noteID: note.id, action: .update, title: note.title)
        }
        #endif

        return note
    }

    func delete(id: UUID) async throws {
        // Ensure directory exists
        try ensureDirectoryExists()

        // Load cache if needed
        try await loadCacheIfNeeded()

        // Soft delete - set deletedAt timestamp and update modified
        guard var note = cache[id] else {
            return  // Idempotent - no error if doesn't exist
        }

        let now = Date()
        note.deletedAt = now
        note.modified = now

        // Write updated note to disk
        try await writeNoteToDisk(note: note)

        // Update cache
        cache[id] = note

        // Trigger git commit if git sync is enabled
        #if os(macOS) || os(iOS)
        if let gitSync = gitSyncService {
            await gitSync.commitNoteChange(noteID: note.id, action: .delete, title: note.title)
        }
        #endif
    }

    func list() async throws -> [Note] {
        // Load cache if needed
        try await loadCacheIfNeeded()

        // Return only non-deleted notes
        return cache.values.filter { !$0.isDeleted }
    }

    func search(query: String) async throws -> [Note] {
        // Load cache if needed
        try await loadCacheIfNeeded()

        let lowercasedQuery = query.lowercased()

        return cache.values.filter { note in
            // Exclude deleted notes
            guard !note.isDeleted else { return false }

            let titleMatch = note.title.lowercased().contains(lowercasedQuery)
            let contentMatch = note.content.lowercased().contains(lowercasedQuery)
            return titleMatch || contentMatch
        }
    }

    // MARK: - Trash Management

    func listTrashed() async throws -> [Note] {
        // Load cache if needed
        try await loadCacheIfNeeded()

        // Return only deleted notes
        return cache.values.filter { $0.isDeleted }
    }

    func restore(id: UUID) async throws {
        // Ensure directory exists
        try ensureDirectoryExists()

        // Load cache if needed
        try await loadCacheIfNeeded()

        // Restore the note and update modified timestamp
        guard var note = cache[id] else {
            throw RepositoryError.noteNotFound(id)
        }

        note.deletedAt = nil
        note.modified = Date()

        // Write updated note to disk
        try await writeNoteToDisk(note: note)

        // Update cache
        cache[id] = note

        // Trigger git commit if git sync is enabled (treat as update)
        #if os(macOS) || os(iOS)
        if let gitSync = gitSyncService {
            await gitSync.commitNoteChange(noteID: note.id, action: .update, title: note.title)
        }
        #endif
    }

    func purge(id: UUID) async throws {
        // Ensure directory exists
        try ensureDirectoryExists()

        // Load cache if needed
        try await loadCacheIfNeeded()

        // Get note title before removing from cache
        let noteTitle = cache[id]?.title ?? "Unknown"

        // Remove from cache
        cache.removeValue(forKey: id)

        // Remove file (idempotent - no error if doesn't exist)
        let filePath = noteFilePath(for: id)
        if fileManager.fileExists(atPath: filePath.path) {
            try fileManager.removeItem(at: filePath)

            // Trigger git commit if git sync is enabled (permanent delete)
            #if os(macOS) || os(iOS)
            if let gitSync = gitSyncService {
                await gitSync.commitNoteChange(noteID: id, action: .delete, title: "Purged: \(noteTitle)")
            }
            #endif
        }
    }

    // MARK: - Private Helpers

    /// Ensure the storage directory exists, creating it if necessary
    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// Load all notes from disk into cache (lazy loading)
    /// Uses Task-based state to prevent concurrent loading
    private func loadCacheIfNeeded() async throws {
        switch cacheState {
        case .loaded:
            // Already loaded, nothing to do
            return

        case .loading(let task):
            // Another task is loading, wait for it to complete
            try await task.value
            return

        case .notLoaded:
            // Create a new loading task
            let loadTask = Task { [weak self] in
                guard let self = self else { return }
                try await self.performCacheLoad()
            }

            // Set state to loading
            cacheState = .loading(loadTask)

            // Wait for load to complete
            try await loadTask.value

            // Mark as loaded
            cacheState = .loaded
        }
    }

    /// Perform the actual cache loading from disk
    private func performCacheLoad() async throws {
        try ensureDirectoryExists()

        // Scan directory for .md files
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let markdownFiles = contents.filter { $0.pathExtension == "md" }

        // Load each note
        for fileURL in markdownFiles {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let note = try formatter.deserialize(content: content)
                cache[note.id] = note
            } catch {
                // Skip corrupt files - we could log this in production
                // For now, just continue loading other files
                continue
            }
        }
    }

    /// Get file path for a note ID
    private func noteFilePath(for id: UUID) -> URL {
        return directory.appendingPathComponent("\(id.uuidString).md")
    }

    /// Write note to disk using atomic write (write to temp, then replace)
    private func writeNoteToDisk(note: Note) async throws {
        let content = formatter.serialize(note: note)
        let finalPath = noteFilePath(for: note.id)

        // Use a hidden temp file in the same directory for atomic replacement
        let tempPath = directory.appendingPathComponent(".\(note.id.uuidString).tmp")

        // Write to temporary file first
        try content.write(to: tempPath, atomically: true, encoding: .utf8)

        // Use replaceItemAt for true atomic replacement
        // If finalPath exists, it will be replaced atomically
        // If it doesn't exist, moveItem will be used as fallback
        if fileManager.fileExists(atPath: finalPath.path) {
            // replaceItemAt ensures the original file is not removed until
            // the replacement is successful, preventing data loss
            _ = try fileManager.replaceItemAt(
                finalPath,
                withItemAt: tempPath,
                backupItemName: nil,
                options: []
            )
        } else {
            // For new files, simple move is safe
            try fileManager.moveItem(at: tempPath, to: finalPath)
        }
    }

    /// Read note from disk
    private func readNoteFromDisk(id: UUID) async throws -> Note {
        let filePath = noteFilePath(for: id)
        let content = try String(contentsOf: filePath, encoding: .utf8)
        return try formatter.deserialize(content: content)
    }
}
