// ABOUTME: Tests for EmbeddingBackgroundService that generates embeddings in background
// ABOUTME: Validates queuing, batch processing, persistence, progress tracking, and error handling

import XCTest
@testable import Template_App

final class EmbeddingBackgroundServiceTests: XCTestCase {
    var service: EmbeddingBackgroundService!
    var mockEmbeddingService: MockDelayedEmbeddingService!
    var mockNoteRepository: MockNoteRepository!
    var mockSearchEngine: MockVectorSearchEngine!
    var tempDirectory: URL!

    override func setUpWithError() throws {
        // Create temp directory for persistence
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        mockEmbeddingService = MockDelayedEmbeddingService()
        mockNoteRepository = MockNoteRepository()
        mockSearchEngine = MockVectorSearchEngine()

        service = EmbeddingBackgroundService(
            embeddingService: mockEmbeddingService,
            noteRepository: mockNoteRepository,
            searchEngine: mockSearchEngine,
            storageDirectory: tempDirectory,
            batchSize: 3
        )
    }

    override func tearDownWithError() throws {
        service = nil
        mockEmbeddingService = nil
        mockNoteRepository = nil
        mockSearchEngine = nil

        // Clean up temp directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Start/Stop Tests

    func testStartBeginsProcessing() async throws {
        // GIVEN service with queued notes
        let noteId = UUID()
        await service.queueNote(id: noteId)

        // WHEN starting service
        await service.start()

        // Wait for processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // THEN isProcessing is true
        let isProcessing = await service.isProcessing
        XCTAssertTrue(isProcessing, "Should be processing after start")
    }

    func testStopPausesProcessing() async throws {
        // GIVEN running service
        await service.start()

        // WHEN stopping service
        await service.stop()

        // THEN isProcessing is false
        let isProcessing = await service.isProcessing
        XCTAssertFalse(isProcessing, "Should not be processing after stop")
    }

    func testMultipleStartCallsAreIdempotent() async throws {
        // GIVEN service
        // WHEN calling start multiple times
        await service.start()
        await service.start()
        await service.start()

        // THEN no crashes and service is running
        let isProcessing = await service.isProcessing
        XCTAssertTrue(isProcessing, "Should be processing")
    }

    // MARK: - Queue Tests

    func testQueueAddsNotes() async throws {
        // GIVEN service
        let noteId = UUID()

        // WHEN queuing note
        await service.queueNote(id: noteId)

        // THEN note is in queue (indirectly verified by processing)
        await service.start()

        // Wait for processing
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Should have attempted to process
        let processedCount = await mockSearchEngine.indexedNotes.count
        XCTAssertGreaterThan(processedCount, 0, "Should have processed queued note")
    }

    func testNotesProcessedInFIFOOrder() async throws {
        // GIVEN multiple queued notes
        let note1 = UUID()
        let note2 = UUID()
        let note3 = UUID()

        await service.queueNote(id: note1)
        await service.queueNote(id: note2)
        await service.queueNote(id: note3)

        // WHEN starting service
        await service.start()

        // Wait for all to process
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        await service.stop()

        // THEN notes processed in order
        let indexed = await mockSearchEngine.indexedNotes
        XCTAssertEqual(indexed.count, 3, "Should have processed all notes")

        // Order should match FIFO
        XCTAssertEqual(indexed[0], note1, "First note should be processed first")
        XCTAssertEqual(indexed[1], note2, "Second note should be processed second")
        XCTAssertEqual(indexed[2], note3, "Third note should be processed third")
    }

    // MARK: - Progress Tests

    func testProgressUpdatesCorrectly() async throws {
        // GIVEN notes to process
        let note1 = UUID()
        let note2 = UUID()

        await service.queueNote(id: note1)
        await service.queueNote(id: note2)

        // WHEN starting service
        await service.start()

        // THEN progress updates from 0.0 to 1.0
        var progressValues: [Float] = []

        // Sample progress
        for _ in 0..<5 {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            let progress = await service.progress
            progressValues.append(progress)
        }

        await service.stop()

        // Progress should increase over time
        XCTAssertTrue(progressValues.last ?? 0 >= progressValues.first ?? 1,
                     "Progress should increase or stay same")
    }

    func testProgressIsOneWhenQueueEmpty() async throws {
        // GIVEN service with no queued notes
        await service.start()

        // Wait a moment
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // WHEN checking progress
        let progress = await service.progress

        // THEN progress is 1.0
        XCTAssertEqual(progress, 1.0, accuracy: 0.01, "Progress should be 1.0 when queue empty")
    }

    // MARK: - Persistence Tests

    func testEmbeddingsPersisted() async throws {
        // GIVEN processed note
        let noteId = UUID()
        await service.queueNote(id: noteId)
        await service.start()

        // Wait for processing
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        await service.stop()

        // THEN embedding file exists
        let embeddingFile = tempDirectory.appendingPathComponent("embeddings.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: embeddingFile.path),
                     "Embeddings file should exist")
    }

    func testEmbeddingsLoadedOnStartup() async throws {
        // GIVEN service that processed notes
        let noteId = UUID()
        await service.queueNote(id: noteId)
        await service.start()

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        await service.stop()

        // WHEN creating new service instance
        let newService = EmbeddingBackgroundService(
            embeddingService: mockEmbeddingService,
            noteRepository: mockNoteRepository,
            searchEngine: mockSearchEngine,
            storageDirectory: tempDirectory,
            batchSize: 3
        )

        // THEN embeddings are loaded
        // (indirectly tested by not reprocessing)
        await newService.queueNote(id: noteId)
        await newService.start()

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        await newService.stop()

        // Should not have generated embedding again (check mock call count)
        let callCount = await mockEmbeddingService.generateCallCount
        XCTAssertLessThanOrEqual(callCount, 1, "Should not regenerate already processed embedding")
    }

    func testSkipAlreadyProcessedNotes() async throws {
        // GIVEN service with processed note
        let noteId = UUID()
        await service.queueNote(id: noteId)
        await service.start()

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        let initialCallCount = await mockEmbeddingService.generateCallCount

        // WHEN queuing same note again
        await service.queueNote(id: noteId)

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        await service.stop()

        // THEN note is not reprocessed
        let finalCallCount = await mockEmbeddingService.generateCallCount
        XCTAssertEqual(finalCallCount, initialCallCount,
                      "Should not reprocess already processed note")
    }

    // MARK: - Batch Processing Tests

    func testBatchProcessing() async throws {
        // GIVEN more notes than batch size
        for _ in 0..<10 {
            await service.queueNote(id: UUID())
        }

        // WHEN starting service
        await service.start()

        // Wait for processing
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        await service.stop()

        // THEN all notes processed
        let indexed = await mockSearchEngine.indexedNotes
        XCTAssertEqual(indexed.count, 10, "Should have processed all notes in batches")
    }

    // MARK: - Error Handling Tests

    func testHandleEmbeddingGenerationError() async throws {
        // GIVEN service and mock that throws error
        await mockEmbeddingService.setShouldFail(true)

        let noteId = UUID()
        await service.queueNote(id: noteId)

        // WHEN starting service
        await service.start()

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        await service.stop()

        // THEN service continues (doesn't crash)
        let isProcessing = await service.isProcessing
        XCTAssertFalse(isProcessing, "Service should have stopped gracefully")
    }

    func testRetryOnError() async throws {
        // GIVEN service with failing then succeeding mock
        await mockEmbeddingService.setShouldFail(true)

        let noteId = UUID()
        await service.queueNote(id: noteId)
        await service.start()

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Fix the mock
        await mockEmbeddingService.setShouldFail(false)

        // Wait for retry
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms

        await service.stop()

        // THEN note eventually processed
        let indexed = await mockSearchEngine.indexedNotes
        XCTAssertGreaterThan(indexed.count, 0, "Should have processed note after retry")
    }

    // MARK: - Integration Tests

    func testIntegrationWithSearchEngine() async throws {
        // GIVEN note in repository
        let note = Note(
            id: UUID(),
            created: Date(),
            device: "test",
            location: nil,
            content: "Test note content",
            title: "Test Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        await mockNoteRepository.addNote(note)

        // WHEN queuing and processing
        await service.queueNote(id: note.id)
        await service.start()

        try await Task.sleep(nanoseconds: 300_000_000) // 300ms

        await service.stop()

        // THEN note indexed in search engine
        let indexed = await mockSearchEngine.indexedNotes
        XCTAssertTrue(indexed.contains(note.id), "Note should be indexed in search engine")
    }
}

// MARK: - Mock Classes

actor MockDelayedEmbeddingService: EmbeddingServiceProtocol {
    var embeddingDimension: Int = 384
    var generateCallCount: Int = 0
    private var shouldFail: Bool = false

    func loadModel() async throws {
        // No-op for mock
    }

    func setShouldFail(_ fail: Bool) {
        shouldFail = fail
    }

    func generateEmbedding(for text: String) async throws -> [Float] {
        // Simulate delay
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        generateCallCount += 1

        if shouldFail {
            throw EmbeddingServiceError.invalidInput
        }

        // Return mock embedding
        return [Float](repeating: 0.5, count: embeddingDimension)
    }

    func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        var results: [[Float]] = []
        for text in texts {
            let embedding = try await generateEmbedding(for: text)
            results.append(embedding)
        }
        return results
    }
}

actor MockNoteRepository: NoteRepository {
    private var notes: [UUID: Note] = [:]

    func addNote(_ note: Note) {
        notes[note.id] = note
    }

    func create(note: Note) async throws -> Note {
        notes[note.id] = note
        return note
    }

    func read(id: UUID) async throws -> Note? {
        return notes[id]
    }

    func update(note: Note) async throws -> Note {
        notes[note.id] = note
        return note
    }

    func delete(id: UUID) async throws {
        notes.removeValue(forKey: id)
    }

    func list(sortedBy: NoteSortOrder) async throws -> [Note] {
        return Array(notes.values)
    }
}

actor MockVectorSearchEngine {
    var indexedNotes: [UUID] = []

    func indexNote(id: UUID, embedding: [Float]) async throws {
        indexedNotes.append(id)
    }

    func removeNote(id: UUID) async {
        indexedNotes.removeAll { $0 == id }
    }

    func search(query: String, threshold: Float) async throws -> [SearchResult] {
        return []
    }

    func rebuild() async {
        indexedNotes.removeAll()
    }
}
