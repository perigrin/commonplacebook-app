// ABOUTME: CRDT-backed note repository with SQLite storage and bidirectional file system sync
// ABOUTME: Thread-safe actor providing conflict-free note management with markdown export/import

import Foundation
import SQLite
import Automerge

/// CRDT-backed repository with SQLite persistence and file system synchronization
actor CRDTNoteRepository: NoteRepository, CRDTNoteRepositoryProtocol {

    private let db: Connection
    private let notesDirectory: URL
    private let crdtService: CRDTService
    private let formatter: NoteFileFormatter
    private let fileManager: FileManager

    // SQLite table definition
    private let notesTable = Table("notes")
    private let idColumn = Expression<String>("id")
    private let crdtDataColumn = Expression<Data>("crdt_data")
    private let filePathColumn = Expression<String>("file_path")
    private let lastModifiedColumn = Expression<Int64>("last_modified")
    // Columns for efficient searching without loading CRDTs
    private let titleColumn = Expression<String>("title")
    private let contentColumn = Expression<String>("content")

    // LRU cache for documents (bounded memory)
    private let maxCacheSize = 100
    private var documentCache: [UUID: DocHandle] = [:]
    private var cacheOrder: [UUID] = []

    // File system watcher
    private var fileWatcher: DispatchSourceFileSystemObject?

    /// Initialize CRDT repository
    /// - Parameters:
    ///   - databasePath: Path to SQLite database file
    ///   - notesDirectory: Directory for markdown file export
    init(databasePath: URL, notesDirectory: URL) throws {
        self.db = try Connection(databasePath.path)
        self.notesDirectory = notesDirectory
        self.crdtService = CRDTService()
        self.formatter = NoteFileFormatter()
        // Create dedicated FileManager instance for thread safety
        self.fileManager = FileManager()

        // Configure SQLite for performance and safety
        try db.execute("PRAGMA journal_mode=WAL")
        try db.execute("PRAGMA busy_timeout=5000")
        try db.execute("PRAGMA synchronous=NORMAL")

        // Create table if needed
        try createTableIfNeeded()

        // Ensure notes directory exists
        try ensureDirectoryExists()

        // Start file system watcher
        startFileSystemWatcher()
    }

    deinit {
        fileWatcher?.cancel()
    }

    // MARK: - Database Setup

    private func createTableIfNeeded() throws {
        try db.run(notesTable.create(ifNotExists: true) { table in
            table.column(idColumn, primaryKey: true)
            table.column(crdtDataColumn)
            table.column(filePathColumn)
            table.column(lastModifiedColumn)
            table.column(titleColumn)
            table.column(contentColumn)
        })

        // Create indexes for efficient searching
        try db.run("CREATE INDEX IF NOT EXISTS idx_title ON notes(title)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_content ON notes(content)")
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: notesDirectory.path) {
            try fileManager.createDirectory(
                at: notesDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - File System Watcher

    private func startFileSystemWatcher() {
        let descriptor = open(notesDirectory.path, O_EVTONLY)
        guard descriptor != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )

        source.setEventHandler { [weak self] in
            Task {
                try? await self?.importExternalChanges()
            }
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.resume()
        self.fileWatcher = source
    }

    // MARK: - LRU Cache Management

    private func cacheDocument(_ id: UUID, _ document: DocHandle) {
        documentCache[id] = document

        // Update LRU order
        cacheOrder.removeAll { $0 == id }
        cacheOrder.append(id)

        // Evict oldest if cache full
        while documentCache.count > maxCacheSize {
            if let oldest = cacheOrder.first {
                documentCache.removeValue(forKey: oldest)
                cacheOrder.removeFirst()
            }
        }
    }

    private func invalidateCache(for id: UUID) {
        documentCache.removeValue(forKey: id)
        cacheOrder.removeAll { $0 == id }
    }

    // MARK: - NoteRepository Protocol

    func create(note: Note) async throws -> Note {
        // Check for duplicate
        if try await read(id: note.id) != nil {
            throw RepositoryError.duplicateNote(note.id)
        }

        // Create CRDT document
        let document = await crdtService.createDocument()
        try await crdtService.updateNote(docHandle: document, note: note)

        // Save to database in transaction
        let crdtData = await crdtService.save(docHandle: document)
        let filePath = noteFilePath(for: note.id).path
        let timestamp = Int64(Date().timeIntervalSince1970)

        try db.transaction {
            try db.run(notesTable.insert(
                idColumn <- note.id.uuidString,
                crdtDataColumn <- crdtData,
                filePathColumn <- filePath,
                lastModifiedColumn <- timestamp,
                titleColumn <- note.title,
                contentColumn <- note.content
            ))
        }

        // Cache document
        cacheDocument(note.id, document)

        // Export to file
        do {
            try exportToFile(note: note)
        } catch {
            // Log but don't fail - file export is best-effort
            print("Warning: Failed to export note \(note.id): \(error)")
        }

        return note
    }

    func read(id: UUID) async throws -> Note? {
        // Try cache first
        if let cachedDoc = documentCache[id] {
            do {
                return try await crdtService.readNote(docHandle: cachedDoc)
            } catch {
                // Cache corrupted - invalidate and reload
                invalidateCache(for: id)
            }
        }

        // Query database
        let query = notesTable.filter(idColumn == id.uuidString)
        guard let row = try db.pluck(query) else {
            return nil
        }

        // Load CRDT document with corruption handling
        let crdtData = row[crdtDataColumn]
        do {
            let document = try await crdtService.load(data: crdtData)
            cacheDocument(id, document)
            return try await crdtService.readNote(docHandle: document)
        } catch {
            // CRDT data corrupted - attempt recovery from file
            print("CRDT data corrupted for note \(id): \(error)")
            do {
                return try await recoverFromFile(id: id)
            } catch {
                print("Recovery failed for note \(id): \(error)")
                return nil
            }
        }
    }

    func update(note: Note) async throws -> Note {
        // Ensure note exists
        guard let existingDoc = try await loadDocument(id: note.id) else {
            throw RepositoryError.noteNotFound(note.id)
        }

        // Update CRDT document
        try await crdtService.updateNote(docHandle: existingDoc, note: note)

        // Save to database in transaction
        let crdtData = await crdtService.save(docHandle: existingDoc)
        let timestamp = Int64(Date().timeIntervalSince1970)

        let query = notesTable.filter(idColumn == note.id.uuidString)
        try db.transaction {
            try db.run(query.update(
                crdtDataColumn <- crdtData,
                lastModifiedColumn <- timestamp,
                titleColumn <- note.title,
                contentColumn <- note.content
            ))
        }

        // Export to file
        do {
            try exportToFile(note: note)
        } catch {
            print("Warning: Failed to export note \(note.id): \(error)")
        }

        return note
    }

    func delete(id: UUID) async throws {
        // Remove from database
        let query = notesTable.filter(idColumn == id.uuidString)
        try db.run(query.delete())

        // Remove from cache
        invalidateCache(for: id)

        // Remove file
        let filePath = noteFilePath(for: id)
        do {
            if fileManager.fileExists(atPath: filePath.path) {
                try fileManager.removeItem(at: filePath)
            }
        } catch {
            // Log error but don't fail (idempotent operation)
            print("Warning: Failed to delete file at \(filePath): \(error)")
        }
    }

    func list() async throws -> [Note] {
        // Load all notes efficiently in batch
        var notes: [Note] = []

        for row in try db.prepare(notesTable.select(idColumn, crdtDataColumn)) {
            guard let id = UUID(uuidString: row[idColumn]) else {
                continue
            }

            do {
                // Load document (will use cache if available)
                let document: DocHandle
                if let cached = documentCache[id] {
                    document = cached
                } else {
                    document = try await crdtService.load(data: row[crdtDataColumn])
                    cacheDocument(id, document)
                }

                let note = try await crdtService.readNote(docHandle: document)
                notes.append(note)
            } catch {
                // Log but continue with other notes
                print("Warning: Failed to load note \(id): \(error)")
            }
        }

        return notes
    }

    func search(query: String) async throws -> [Note] {
        // Use SQLite for efficient filtering
        let pattern = "%\(query)%"
        let filteredTable = notesTable.filter(
            titleColumn.like(pattern) || contentColumn.like(pattern)
        )

        var notes: [Note] = []

        for row in try db.prepare(filteredTable.select(idColumn, crdtDataColumn)) {
            guard let id = UUID(uuidString: row[idColumn]) else {
                continue
            }

            do {
                let document: DocHandle
                if let cached = documentCache[id] {
                    document = cached
                } else {
                    document = try await crdtService.load(data: row[crdtDataColumn])
                    cacheDocument(id, document)
                }

                let note = try await crdtService.readNote(docHandle: document)
                notes.append(note)
            } catch {
                print("Warning: Failed to load note \(id) during search: \(error)")
            }
        }

        return notes
    }

    // MARK: - File System Sync

    private func exportToFile(note: Note) throws {
        let filePath = noteFilePath(for: note.id)
        let markdown = formatter.serialize(note: note)

        // Write with retry logic for transient failures
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                try markdown.write(to: filePath, atomically: true, encoding: .utf8)
                return
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 100_000_000))
                }
            }
        }
        throw lastError ?? RepositoryError.storageError("Export failed after retries")
    }

    /// Import external file changes into CRDT
    func importExternalChanges() async throws {
        // Scan notes directory for markdown files
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter({ $0.pathExtension == "md" }) else {
            return
        }

        for fileURL in fileURLs {
            // Extract and validate ID from filename
            let filename = fileURL.deletingPathExtension().lastPathComponent
            guard let id = UUID(uuidString: filename),
                  !filename.contains("/") && !filename.contains("..") else {
                continue
            }

            // Import the file
            do {
                try await importFileChange(fileURL: fileURL, id: id)
            } catch {
                print("Warning: Failed to import file \(fileURL.lastPathComponent): \(error)")
            }
        }
    }

    private func importFileChange(fileURL: URL, id: UUID) async throws {
        // Read file content
        guard let fileContent = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return
        }

        // Parse note from markdown with fallback
        let parsedNote: Note
        do {
            parsedNote = try formatter.deserialize(content: fileContent)
        } catch {
            // Fallback: create note with raw content to preserve data
            print("Warning: Parse error for \(fileURL.lastPathComponent), using fallback: \(error)")
            parsedNote = Note(
                id: id,
                created: Date(),
                device: "External Edit",
                location: nil,
                content: fileContent,
                title: fileURL.deletingPathExtension().lastPathComponent,
                backlinks: [],
                unknownFrontmatterFields: [:]
            )
        }

        // Load or create CRDT document
        let document: DocHandle
        if let existingDoc = try await loadDocument(id: id) {
            // Merge external changes via CRDT
            let externalDoc = await crdtService.createDocument()
            try await crdtService.updateNote(docHandle: externalDoc, note: parsedNote)

            // Merge documents
            do {
                document = try await crdtService.merge(doc1: existingDoc, doc2: externalDoc)
            } catch {
                throw RepositoryError.concurrencyError("Merge failed: \(error)")
            }
        } else {
            // New note - create fresh document
            document = await crdtService.createDocument()
            try await crdtService.updateNote(docHandle: document, note: parsedNote)
        }

        // Update cache with merged document
        cacheDocument(id, document)

        // Save merged result to database
        let mergedNote = try await crdtService.readNote(docHandle: document)
        let crdtData = await crdtService.save(docHandle: document)
        let timestamp = Int64(Date().timeIntervalSince1970)

        let query = notesTable.filter(idColumn == id.uuidString)
        try db.transaction {
            if try db.pluck(query) != nil {
                // Update existing
                try db.run(query.update(
                    crdtDataColumn <- crdtData,
                    lastModifiedColumn <- timestamp,
                    titleColumn <- mergedNote.title,
                    contentColumn <- mergedNote.content
                ))
            } else {
                // Insert new
                try db.run(notesTable.insert(
                    idColumn <- id.uuidString,
                    crdtDataColumn <- crdtData,
                    filePathColumn <- fileURL.path,
                    lastModifiedColumn <- timestamp,
                    titleColumn <- mergedNote.title,
                    contentColumn <- mergedNote.content
                ))
            }
        }
    }

    // MARK: - Helper Methods

    private func loadDocument(id: UUID) async throws -> DocHandle? {
        // Check cache first
        if let cached = documentCache[id] {
            return cached
        }

        // Load from database
        let query = notesTable.filter(idColumn == id.uuidString)
        guard let row = try db.pluck(query) else {
            return nil
        }

        let crdtData = row[crdtDataColumn]
        let document = try await crdtService.load(data: crdtData)
        cacheDocument(id, document)
        return document
    }

    private func recoverFromFile(id: UUID) async throws -> Note {
        let filePath = noteFilePath(for: id)
        let fileContent = try String(contentsOf: filePath, encoding: .utf8)
        return try formatter.deserialize(content: fileContent)
    }

    private func noteFilePath(for id: UUID) -> URL {
        // Sanitize UUID (though UUIDs are safe, validate anyway)
        let sanitizedId = id.uuidString.replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "..", with: "")
        return notesDirectory.appendingPathComponent("\(sanitizedId).md")
    }

    // MARK: - CRDTNoteRepositoryProtocol Methods

    /// Get raw CRDT data for a note (for syncing)
    func getCRDTData(for id: UUID) async throws -> Data? {
        let query = notesTable.filter(idColumn == id.uuidString)
        guard let row = try db.pluck(query) else {
            return nil
        }
        return row[crdtDataColumn]
    }

    /// List notes modified since a date
    func listModifiedSince(_ date: Date) async throws -> [Note] {
        let timestamp = Int64(date.timeIntervalSince1970)
        let query = notesTable.filter(lastModifiedColumn > timestamp)

        var notes: [Note] = []
        for row in try db.prepare(query.select(idColumn, crdtDataColumn)) {
            guard let id = UUID(uuidString: row[idColumn]) else {
                continue
            }

            if let note = try await read(id: id) {
                notes.append(note)
            }
        }

        return notes
    }

    /// Get all note IDs (for detecting deletes)
    func getAllNoteIDs() async throws -> Set<UUID> {
        var ids = Set<UUID>()

        for row in try db.prepare(notesTable.select(idColumn)) {
            if let id = UUID(uuidString: row[idColumn]) {
                ids.insert(id)
            }
        }

        return ids
    }
}
