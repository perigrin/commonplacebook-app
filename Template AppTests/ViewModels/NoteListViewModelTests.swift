// ABOUTME: Tests for note list view model
// ABOUTME: Covers loading, sorting, creating, deleting notes with MVVM pattern

import XCTest
@testable import CommonplaceBook

@MainActor
final class NoteListViewModelTests: XCTestCase {

    var repository: InMemoryNoteRepository!
    var viewModel: NoteListViewModel!

    override func setUp() async throws {
        try await super.setUp()
        repository = InMemoryNoteRepository()
    }

    override func tearDown() async throws {
        viewModel = nil
        repository = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializeWithRepository() async {
        // When
        viewModel = NoteListViewModel(repository: repository)

        // Then
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertEqual(viewModel.notes.count, 0, "Notes should be empty on init")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading on init")
        XCTAssertNil(viewModel.error, "Should have no error on init")
    }

    // MARK: - Load Notes Tests

    func testLoadNotesPopulatesArray() async {
        // Given
        let note1 = createTestNote(title: "Note 1", content: "Content 1")
        let note2 = createTestNote(title: "Note 2", content: "Content 2")
        let note3 = createTestNote(title: "Note 3", content: "Content 3")

        _ = try? await repository.create(note: note1)
        _ = try? await repository.create(note: note2)
        _ = try? await repository.create(note: note3)

        viewModel = NoteListViewModel(repository: repository)

        // When
        await viewModel.loadNotes()

        // Then
        XCTAssertEqual(viewModel.notes.count, 3, "Should load all notes")
        XCTAssertNil(viewModel.error, "Should have no error")
    }

    func testLoadNotesSortsByCreatedDateNewestFirst() async {
        // Given
        let oldDate = Date(timeIntervalSinceNow: -10000)
        let middleDate = Date(timeIntervalSinceNow: -5000)
        let recentDate = Date()

        let oldNote = createTestNote(title: "Old", content: "Content", created: oldDate)
        let middleNote = createTestNote(title: "Middle", content: "Content", created: middleDate)
        let recentNote = createTestNote(title: "Recent", content: "Content", created: recentDate)

        _ = try? await repository.create(note: oldNote)
        _ = try? await repository.create(note: middleNote)
        _ = try? await repository.create(note: recentNote)

        viewModel = NoteListViewModel(repository: repository)

        // When
        await viewModel.loadNotes()

        // Then
        XCTAssertEqual(viewModel.notes.count, 3)
        XCTAssertEqual(viewModel.notes[0].title, "Recent", "Most recent should be first")
        XCTAssertEqual(viewModel.notes[1].title, "Middle", "Middle should be second")
        XCTAssertEqual(viewModel.notes[2].title, "Old", "Oldest should be last")
    }

    func testLoadNotesHandlesEmptyRepository() async {
        // Given
        viewModel = NoteListViewModel(repository: repository)

        // When
        await viewModel.loadNotes()

        // Then
        XCTAssertEqual(viewModel.notes.count, 0, "Should handle empty repository")
        XCTAssertNil(viewModel.error, "Should have no error")
    }

    func testLoadNotesSetsIsLoadingCorrectly() async {
        // Given
        viewModel = NoteListViewModel(repository: repository)

        // When/Then
        XCTAssertFalse(viewModel.isLoading, "Should not be loading before loadNotes()")

        await viewModel.loadNotes()

        XCTAssertFalse(viewModel.isLoading, "Should not be loading after loadNotes() completes")
    }

    func testLoadNotesHandlesRepositoryError() async {
        // Given
        let failingRepository = FailingRepository()
        viewModel = NoteListViewModel(repository: failingRepository)

        // When
        await viewModel.loadNotes()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error when repository fails")
        XCTAssertEqual(viewModel.notes.count, 0, "Notes should be empty on error")
    }

    // MARK: - Create Note Tests

    func testCreateNoteAddsToList() async {
        // Given
        viewModel = NoteListViewModel(repository: repository)
        await viewModel.loadNotes()
        let initialCount = viewModel.notes.count

        // When
        let newNote = await viewModel.createNote(title: "New Note", content: "New content")

        // Then
        XCTAssertNotNil(newNote, "Should return created note")
        XCTAssertEqual(viewModel.notes.count, initialCount + 1, "Should add note to list")
        XCTAssertTrue(viewModel.notes.contains { $0.id == newNote?.id }, "Should contain new note")
        XCTAssertNil(viewModel.error, "Should have no error")
    }

    func testCreateNoteAddsMetadataAutomatically() async {
        // Given
        viewModel = NoteListViewModel(repository: repository)
        await viewModel.loadNotes()

        // When
        let newNote = await viewModel.createNote(title: "Test", content: "Content")

        // Then
        XCTAssertNotNil(newNote, "Should create note")
        XCTAssertNotNil(newNote?.id, "Should have UUID")
        XCTAssertNotNil(newNote?.created, "Should have created date")
        XCTAssertFalse(newNote?.device.isEmpty ?? true, "Should have device name")

        // Verify note appears first (most recent)
        XCTAssertEqual(viewModel.notes.first?.id, newNote?.id, "New note should be first")
    }

    func testCreateNoteHandlesRepositoryError() async {
        // Given
        let failingRepository = FailingRepository()
        viewModel = NoteListViewModel(repository: failingRepository)

        // When
        let newNote = await viewModel.createNote(title: "Test", content: "Content")

        // Then
        XCTAssertNil(newNote, "Should return nil on error")
        XCTAssertNotNil(viewModel.error, "Should set error")
    }

    // MARK: - Delete Note Tests

    func testDeleteNoteRemovesFromList() async {
        // Given
        let note = createTestNote(title: "To Delete", content: "Content")
        _ = try? await repository.create(note: note)

        viewModel = NoteListViewModel(repository: repository)
        await viewModel.loadNotes()

        let initialCount = viewModel.notes.count
        XCTAssertTrue(viewModel.notes.contains { $0.id == note.id }, "Note should exist initially")

        // When
        await viewModel.deleteNote(id: note.id)

        // Then
        XCTAssertEqual(viewModel.notes.count, initialCount - 1, "Should remove note from list")
        XCTAssertFalse(viewModel.notes.contains { $0.id == note.id }, "Should not contain deleted note")
        XCTAssertNil(viewModel.error, "Should have no error")
    }

    func testDeleteNoteRemovesFromRepository() async {
        // Given
        let note = createTestNote(title: "To Delete", content: "Content")
        _ = try? await repository.create(note: note)

        viewModel = NoteListViewModel(repository: repository)
        await viewModel.loadNotes()

        // When
        await viewModel.deleteNote(id: note.id)

        // Then
        let noteInRepo = try? await repository.read(id: note.id)
        XCTAssertNil(noteInRepo, "Note should be deleted from repository")
    }

    func testDeleteNoteIsIdempotent() async {
        // Given
        let noteId = UUID()
        viewModel = NoteListViewModel(repository: repository)
        await viewModel.loadNotes()

        // When/Then - Should not throw error
        await viewModel.deleteNote(id: noteId)
        await viewModel.deleteNote(id: noteId) // Delete again

        XCTAssertNil(viewModel.error, "Should not error on idempotent delete")
    }

    func testDeleteNoteHandlesRepositoryError() async {
        // Given
        let failingRepository = FailingRepository()
        viewModel = NoteListViewModel(repository: failingRepository)

        // When
        await viewModel.deleteNote(id: UUID())

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error when repository fails")
    }

    // MARK: - Refresh Tests

    func testRefreshUpdatesListFromRepository() async {
        // Given
        let note1 = createTestNote(title: "Note 1", content: "Content 1")
        _ = try? await repository.create(note: note1)

        viewModel = NoteListViewModel(repository: repository)
        await viewModel.loadNotes()
        XCTAssertEqual(viewModel.notes.count, 1)

        // Add more notes to repository
        let note2 = createTestNote(title: "Note 2", content: "Content 2")
        let note3 = createTestNote(title: "Note 3", content: "Content 3")
        _ = try? await repository.create(note: note2)
        _ = try? await repository.create(note: note3)

        // When
        await viewModel.refresh()

        // Then
        XCTAssertEqual(viewModel.notes.count, 3, "Should load all notes after refresh")
        XCTAssertNil(viewModel.error, "Should have no error")
    }

    func testRefreshClearsExistingNotes() async {
        // Given
        let note1 = createTestNote(title: "Note 1", content: "Content 1")
        let note2 = createTestNote(title: "Note 2", content: "Content 2")
        _ = try? await repository.create(note: note1)
        _ = try? await repository.create(note: note2)

        viewModel = NoteListViewModel(repository: repository)
        await viewModel.loadNotes()
        XCTAssertEqual(viewModel.notes.count, 2)

        // Delete a note from repository directly
        try? await repository.delete(id: note1.id)

        // When
        await viewModel.refresh()

        // Then
        XCTAssertEqual(viewModel.notes.count, 1, "Should reflect repository state")
        XCTAssertFalse(viewModel.notes.contains { $0.id == note1.id }, "Deleted note should not appear")
    }

    func testRefreshHandlesRepositoryError() async {
        // Given
        let failingRepository = FailingRepository()
        viewModel = NoteListViewModel(repository: failingRepository)

        // When
        await viewModel.refresh()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error when repository fails")
    }

    // MARK: - Error Handling Tests

    func testErrorIsPublished() async {
        // Given
        let failingRepository = FailingRepository()
        viewModel = NoteListViewModel(repository: failingRepository)

        // When
        await viewModel.loadNotes()

        // Then
        XCTAssertNotNil(viewModel.error, "Error should be published")
    }

    func testSuccessfulOperationClearsError() async {
        // Given
        let failingRepository = FailingRepository()
        viewModel = NoteListViewModel(repository: failingRepository)
        await viewModel.loadNotes()
        XCTAssertNotNil(viewModel.error, "Should have error initially")

        // When - Switch to working repository
        viewModel = NoteListViewModel(repository: repository)
        await viewModel.loadNotes()

        // Then
        XCTAssertNil(viewModel.error, "Should clear error after successful operation")
    }

    // MARK: - Concurrent Operations Tests

    func testConcurrentCreateOperations() async {
        // Given
        viewModel = NoteListViewModel(repository: repository)
        await viewModel.loadNotes()

        // When - Create 10 notes concurrently
        await withTaskGroup(of: Note?.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await self.viewModel.createNote(title: "Note \(i)", content: "Content \(i)")
                }
            }
        }

        // Then
        XCTAssertEqual(viewModel.notes.count, 10, "All notes should be created")
        XCTAssertNil(viewModel.error, "Should have no error")
    }

    // MARK: - Helper Methods

    private func createTestNote(title: String, content: String, created: Date = Date()) -> Note {
        return Note(
            id: UUID(),
            created: created,
            device: "TestDevice",
            location: nil,
            content: content,
            title: title,
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
    }
}
