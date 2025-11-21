// ABOUTME: CRDT-backed note repository with SQLite storage and bidirectional file system sync
// ABOUTME: Thread-safe actor providing conflict-free note management with markdown export/import

import Foundation
import SQLite
import Automerge

/// CRDT-backed repository with SQLite persistence and file system synchronization
actor CRDTNoteRepository: NoteRepository, CRDTNoteRepositoryProtocol {

    private nonisolated(unsafe) let db: Connection
    private let notesDirectory: URL
    private let crdtService: CRDTService
    private nonisolated(unsafe) let formatter: NoteFileFormatter
    private nonisolated(unsafe) let fileManager: FileManager

    // SQLite table definition
    private nonisolated(unsafe) let notesTable = Table("notes")
    private nonisolated(unsafe) let idColumn: Expression<String> = .init("id")
    private nonisolated(unsafe) let crdtDataColumn: Expression<Data> = .init("crdt_data")
    private nonisolated(unsafe) let filePathColumn: Expression<String> = .init("file_path")
    private nonisolated(unsafe) let lastModifiedColumn: Expression<Int64> = .init("last_modified")
    // Columns for efficient searching without loading CRDTs
    private nonisolated(unsafe) let titleColumn: Expression<String> = .init("title")
    private nonisolated(unsafe) let contentColumn: Expression<String> = .init("content")

    // Tombstone table for delete tracking
    private nonisolated(unsafe) let tombstonesTable = Table("tombstones")
    private nonisolated(unsafe) let tombstoneIdColumn: Expression<String> = .init("id")
    private nonisolated(unsafe) let tombstoneDeletedAtColumn: Expression<Int64> = .init("deleted_at")

    // LRU cache for documents (bounded memory)
    private let maxCacheSize = 500  // Increased from 100
    private var documentCache: [UUID: DocHandle] = [:]
    private var cacheOrder: [UUID] = []
    private var activeDocuments: Set<UUID> = []  // Track documents in use

    // Track document usage with reference counts
    private var documentRefCounts: [UUID: Int] = [:]

    // File system watcher
    private nonisolated(unsafe) var fileWatcher: DispatchSourceFileSystemObject?

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

        // Clean up tombstones older than 30 days on initialization
        try? cleanupOldTombstones(olderThan: 30)

        // Ensure notes directory exists
        try ensureDirectoryExists()

        // Start file system watcher
        startFileSystemWatcher()
    }

    deinit {
        fileWatcher?.cancel()
    }

    // MARK: - Database Setup

    private nonisolated func createTableIfNeeded() throws {
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

        // Add index on last_modified for listModifiedSince queries
        try db.run("CREATE INDEX IF NOT EXISTS idx_notes_last_modified ON notes(last_modified)")

        // Create tombstones table
        try db.run(tombstonesTable.create(ifNotExists: true) { table in
            table.column(tombstoneIdColumn, primaryKey: true)
            table.column(tombstoneDeletedAtColumn)
        })

        // Add index on tombstone deleted_at for efficient cleanup
        try db.run("CREATE INDEX IF NOT EXISTS idx_tombstone_deleted_at ON tombstones(deleted_at)")
    }

    private func validateCRDTData(_ data: Data) async -> Bool {
        // Check minimum size (Automerge documents have minimum structure)
        guard data.count >= 100 else {
            print("CRDT data too small: \(data.count) bytes")
            return false
        }

        // Check maximum size
        let maxSize = 10 * 1024 * 1024  // 10MB
        guard data.count < maxSize else {
            print("CRDT data too large: \(data.count) bytes")
            return false
        }

        // Add timeout for validation to prevent blocking
        do {
            try await withTimeout(seconds: 5) {
                let doc = try await self.crdtService.load(data: data)
                _ = try await self.crdtService.readNote(docHandle: doc)
            }
            return true
        } catch {
            print("CRDT data validation failed: \(error)")
            return false
        }
    }

    // Helper function for timeout
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw RepositoryError.operationTimeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private nonisolated func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: notesDirectory.path) {
            try fileManager.createDirectory(
                at: notesDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - File System Watcher

    private nonisolated func startFileSystemWatcher() {
        let descriptor = open(notesDirectory.path, O_EVTONLY)
        guard descriptor != -1 else {
            print("Failed to open file descriptor for watching")
            return
        }

        // Track whether we successfully created the watcher
        var watcherCreated = false

        defer {
            // Only close if we failed to create watcher
            if !watcherCreated {
                close(descriptor)
            }
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .background)
        )

        source.setEventHandler { [weak self] in
            Task {
                try? await self?.importExternalChanges()
            }
        }

        source.setCancelHandler {
            // This owns the descriptor now, will close it when cancelled
            close(descriptor)
        }

        // Activate the source first
        source.resume()

        // Then assign to property - this transfers ownership
        self.fileWatcher = source

        // Mark successful creation AFTER assignment
        watcherCreated = true
    }

    // MARK: - LRU Cache Management

    private func cacheDocument(_ id: UUID, _ document: DocHandle) {
        // Remove existing entry if present
        if let existingIndex = cacheOrder.firstIndex(of: id) {
            cacheOrder.remove(at: existingIndex)
        }

        // Add to front of queue
        cacheOrder.insert(id, at: 0)
        documentCache[id] = document

        // Evict oldest non-active documents if over limit
        var attempts = 0
        let maxAttempts = cacheOrder.count + 1

        while documentCache.count > maxCacheSize && attempts < maxAttempts {
            attempts += 1

            guard let oldestId = cacheOrder.last else { break }

            // Check if document has active references
            if let refCount = documentRefCounts[oldestId], refCount > 0 {
                // Move to front to try next time
                cacheOrder.removeLast()
                cacheOrder.insert(oldestId, at: 0)
                continue
            }

            // Safe to evict - no active references
            cacheOrder.removeLast()
            documentCache.removeValue(forKey: oldestId)
        }

        // If still over limit, warn but DON'T force evict
        if documentCache.count > maxCacheSize {
            print("WARNING: Cache size (\(documentCache.count)) exceeds limit (\(maxCacheSize))")
            print("Active references: \(documentRefCounts.filter { $0.value > 0 }.count) documents")
            // Consider increasing maxCacheSize dynamically here
        }
    }

    private func invalidateCache(for id: UUID) {
        documentCache.removeValue(forKey: id)
        cacheOrder.removeAll { $0 == id }
    }

    private func markActive(id: UUID) {
        documentRefCounts[id, default: 0] += 1
    }

    private func markInactive(id: UUID) {
        if let count = documentRefCounts[id], count > 0 {
            documentRefCounts[id] = count - 1
            if count == 1 {
                documentRefCounts.removeValue(forKey: id)
            }
        }
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
            try await exportToFile(note: note)
        } catch {
            // Log but don't fail - file export is best-effort
            print("Warning: Failed to export note \(note.id): \(error)")
        }

        return note
    }

    func read(id: UUID) async throws -> Note? {
        markActive(id: id)
        defer { markInactive(id: id) }

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
        markActive(id: note.id)
        defer { markInactive(id: note.id) }

        // Ensure note exists
        guard let existingDoc = try await loadDocument(id: note.id) else {
            throw RepositoryError.noteNotFound(note.id)
        }

        // Invalidate cache before modification to prevent corruption if transaction fails
        invalidateCache(for: note.id)

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

        // Cache document ONLY AFTER successful transaction
        cacheDocument(note.id, existingDoc)

        // Export to file
        do {
            try await exportToFile(note: note)
        } catch {
            print("Warning: Failed to export note \(note.id): \(error)")
        }

        return note
    }

    func delete(id: UUID) async throws {
        markActive(id: id)
        defer { markInactive(id: id) }

        // Soft delete - set deletedAt timestamp and update modified
        guard var note = try await read(id: id) else {
            return  // Idempotent - no error if doesn't exist
        }

        let now = Date()
        note.deletedAt = now
        note.modified = now

        // Update note in CRDT and database
        guard let existingDoc = try await loadDocument(id: id) else {
            return
        }

        // Invalidate cache before modification
        invalidateCache(for: id)

        // Update CRDT document with deletedAt
        try await crdtService.updateNote(docHandle: existingDoc, note: note)

        // Save to database in transaction
        let crdtData = await crdtService.save(docHandle: existingDoc)
        let timestamp = Int64(Date().timeIntervalSince1970)

        let query = notesTable.filter(idColumn == id.uuidString)
        try db.transaction {
            try db.run(query.update(
                crdtDataColumn <- crdtData,
                lastModifiedColumn <- timestamp,
                titleColumn <- note.title,
                contentColumn <- note.content
            ))
        }

        // Cache document ONLY AFTER successful transaction
        cacheDocument(id, existingDoc)

        // Export to file (soft deleted notes remain in file system)
        do {
            try await exportToFile(note: note)
        } catch {
            print("Warning: Failed to export deleted note \(id): \(error)")
        }
    }

    func list() async throws -> [Note] {
        let totalCount = try count()

        // Hard limit to prevent memory exhaustion
        let maxLoad = 5000
        if totalCount > maxLoad {
            throw RepositoryError.collectionTooLarge(
                "Collection has \(totalCount) notes, maximum \(maxLoad) allowed. Use list(limit:offset:) for pagination."
            )
        }

        if totalCount > 1000 {
            print("Warning: Loading \(totalCount) notes into memory. Consider using list(limit:offset:)")
        }

        return try await list(limit: totalCount, offset: 0)
    }

    func list(limit: Int, offset: Int = 0) async throws -> [Note] {
        // Load notes with pagination to prevent memory exhaustion
        var notes: [Note] = []

        let query = notesTable
            .order(lastModifiedColumn.desc)
            .limit(limit, offset: offset)

        for row in try db.prepare(query.select(idColumn, crdtDataColumn)) {
            guard let id = UUID(uuidString: row[idColumn]) else {
                continue
            }

            markActive(id: id)
            defer { markInactive(id: id) }

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

                // Exclude deleted notes
                if !note.isDeleted {
                    notes.append(note)
                }
            } catch {
                // Log but continue with other notes
                print("Warning: Failed to load note \(id): \(error)")
            }
        }

        return notes
    }

    func count() throws -> Int {
        return try db.scalar(notesTable.count)
    }

    func search(query: String) async throws -> [Note] {
        // Escape special LIKE characters to prevent SQL injection
        let escapedQuery = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "[", with: "\\[")

        let pattern = "%\(escapedQuery)%"

        // Use escaped pattern with escape character
        let filteredTable = notesTable.filter(
            titleColumn.like(pattern, escape: "\\") || contentColumn.like(pattern, escape: "\\")
        )

        var notes: [Note] = []

        for row in try db.prepare(filteredTable.select(idColumn, crdtDataColumn)) {
            guard let id = UUID(uuidString: row[idColumn]) else {
                continue
            }

            markActive(id: id)
            defer { markInactive(id: id) }

            do {
                let document: DocHandle
                if let cached = documentCache[id] {
                    document = cached
                } else {
                    document = try await crdtService.load(data: row[crdtDataColumn])
                    cacheDocument(id, document)
                }

                let note = try await crdtService.readNote(docHandle: document)

                // Exclude deleted notes
                if !note.isDeleted {
                    notes.append(note)
                }
            } catch {
                print("Warning: Failed to load note \(id) during search: \(error)")
            }
        }

        return notes
    }

    // MARK: - Trash Management

    func listTrashed() async throws -> [Note] {
        // Load all notes and filter for deleted ones
        var trashedNotes: [Note] = []

        for row in try db.prepare(notesTable.select(idColumn, crdtDataColumn)) {
            guard let id = UUID(uuidString: row[idColumn]) else {
                continue
            }

            markActive(id: id)
            defer { markInactive(id: id) }

            do {
                let document: DocHandle
                if let cached = documentCache[id] {
                    document = cached
                } else {
                    document = try await crdtService.load(data: row[crdtDataColumn])
                    cacheDocument(id, document)
                }

                let note = try await crdtService.readNote(docHandle: document)

                // Include only deleted notes
                if note.isDeleted {
                    trashedNotes.append(note)
                }
            } catch {
                print("Warning: Failed to load note \(id) in trash: \(error)")
            }
        }

        return trashedNotes
    }

    func restore(id: UUID) async throws {
        markActive(id: id)
        defer { markInactive(id: id) }

        // Restore the note by clearing deletedAt and updating modified timestamp
        guard var note = try await read(id: id) else {
            throw RepositoryError.noteNotFound(id)
        }

        note.deletedAt = nil
        note.modified = Date()

        // Update note in CRDT and database
        guard let existingDoc = try await loadDocument(id: id) else {
            throw RepositoryError.noteNotFound(id)
        }

        // Invalidate cache before modification
        invalidateCache(for: id)

        // Update CRDT document with cleared deletedAt
        try await crdtService.updateNote(docHandle: existingDoc, note: note)

        // Save to database in transaction
        let crdtData = await crdtService.save(docHandle: existingDoc)
        let timestamp = Int64(Date().timeIntervalSince1970)

        let query = notesTable.filter(idColumn == id.uuidString)
        try db.transaction {
            try db.run(query.update(
                crdtDataColumn <- crdtData,
                lastModifiedColumn <- timestamp,
                titleColumn <- note.title,
                contentColumn <- note.content
            ))
        }

        // Cache document ONLY AFTER successful transaction
        cacheDocument(id, existingDoc)

        // Export to file
        do {
            try await exportToFile(note: note)
        } catch {
            print("Warning: Failed to export restored note \(id): \(error)")
        }
    }

    func purge(id: UUID) async throws {
        markActive(id: id)
        defer { markInactive(id: id) }

        // Track deletion before removing from database
        try trackDeletion(id: id)

        // Remove from database (hard delete)
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

    // MARK: - File System Sync

    private func exportToFile(note: Note) async throws {
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
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 100_000_000))
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
        markActive(id: id)
        defer { markInactive(id: id) }

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

        // Cache document ONLY AFTER successful transaction
        cacheDocument(id, document)
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

    /// Save CRDT data for a note (for persisting reconstructed data)
    func saveCRDTData(for id: UUID, data: Data) async throws {
        // Validate CRDT data before persisting
        guard await validateCRDTData(data) else {
            throw RepositoryError.invalidCRDTData
        }

        markActive(id: id)
        defer { markInactive(id: id) }

        let query = notesTable.filter(idColumn == id.uuidString)

        // Verify note exists
        guard try db.pluck(query) != nil else {
            throw RepositoryError.noteNotFound(id)
        }

        // Update CRDT data in transaction
        try db.transaction {
            try db.run(query.update(
                crdtDataColumn <- data,
                lastModifiedColumn <- Int64(Date().timeIntervalSince1970)
            ))
        }

        // Invalidate cache to force reload with new CRDT data
        invalidateCache(for: id)
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

    // MARK: - Tombstone Methods

    /// Track deletion for sync
    func trackDeletion(id: UUID) throws {
        try db.run(tombstonesTable.insert(or: .replace,
            tombstoneIdColumn <- id.uuidString,
            tombstoneDeletedAtColumn <- Int64(Date().timeIntervalSince1970)
        ))
    }

    /// Get IDs deleted since a date
    func getDeletedSince(_ date: Date) throws -> [UUID] {
        let timestamp = Int64(date.timeIntervalSince1970)
        let query = tombstonesTable.filter(tombstoneDeletedAtColumn > timestamp)
        return try db.prepare(query).compactMap { row in
            UUID(uuidString: row[tombstoneIdColumn])
        }
    }

    /// Clear tombstone after successful sync
    func clearTombstone(id: UUID) throws {
        try db.run(tombstonesTable.filter(tombstoneIdColumn == id.uuidString).delete())
    }

    /// Clean up old tombstones to prevent unbounded growth
    nonisolated func cleanupOldTombstones(olderThan days: Int = 30) throws {
        let cutoff = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
        let cutoffTimestamp = Int64(cutoff.timeIntervalSince1970)
        try db.run(tombstonesTable.filter(tombstoneDeletedAtColumn < cutoffTimestamp).delete())
    }
}
