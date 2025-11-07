// ABOUTME: File system-based note repository with atomic writes and in-memory caching
// ABOUTME: Thread-safe actor that persists notes as markdown files with YAML frontmatter

import Foundation

/// File system note repository with atomic writes and caching
actor FileSystemNoteRepository: NoteRepository {

    private let directory: URL
    private let formatter: NoteFileFormatter
    private let fileManager: FileManager

    // In-memory cache for performance
    private var cache: [UUID: Note] = [:]
    private var cacheLoaded = false

    init(directory: URL) {
        self.directory = directory
        self.formatter = NoteFileFormatter()
        self.fileManager = FileManager.default
    }

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

        return note
    }

    func delete(id: UUID) async throws {
        // Ensure directory exists
        try ensureDirectoryExists()

        // Load cache if needed
        try await loadCacheIfNeeded()

        // Remove from cache
        cache.removeValue(forKey: id)

        // Remove file (idempotent - no error if doesn't exist)
        let filePath = noteFilePath(for: id)
        if fileManager.fileExists(atPath: filePath.path) {
            try fileManager.removeItem(at: filePath)
        }
    }

    func list() async throws -> [Note] {
        // Load cache if needed
        try await loadCacheIfNeeded()

        return Array(cache.values)
    }

    func search(query: String) async throws -> [Note] {
        // Load cache if needed
        try await loadCacheIfNeeded()

        let lowercasedQuery = query.lowercased()

        return cache.values.filter { note in
            let titleMatch = note.title.lowercased().contains(lowercasedQuery)
            let contentMatch = note.content.lowercased().contains(lowercasedQuery)
            return titleMatch || contentMatch
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
    private func loadCacheIfNeeded() async throws {
        guard !cacheLoaded else { return }

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

        cacheLoaded = true
    }

    /// Get file path for a note ID
    private func noteFilePath(for id: UUID) -> URL {
        return directory.appendingPathComponent("\(id.uuidString).md")
    }

    /// Write note to disk using atomic write (write to temp, then rename)
    private func writeNoteToDisk(note: Note) async throws {
        let content = formatter.serialize(note: note)
        let finalPath = noteFilePath(for: note.id)

        // Atomic write: write to temporary file, then rename
        // This ensures the file is never in a partial state
        let tempPath = directory.appendingPathComponent("\(UUID().uuidString).tmp")

        try content.write(to: tempPath, atomically: true, encoding: .utf8)

        // Rename temp file to final path (atomic operation on most filesystems)
        if fileManager.fileExists(atPath: finalPath.path) {
            try fileManager.removeItem(at: finalPath)
        }
        try fileManager.moveItem(at: tempPath, to: finalPath)
    }

    /// Read note from disk
    private func readNoteFromDisk(id: UUID) async throws -> Note {
        let filePath = noteFilePath(for: id)
        let content = try String(contentsOf: filePath, encoding: .utf8)
        return try formatter.deserialize(content: content)
    }
}
