// ABOUTME: Tests for note display/editing view model
// ABOUTME: Covers loading, saving, validation, and error handling with MVVM pattern

import XCTest
@testable import CommonplaceBook

@MainActor
final class NoteViewModelTests: XCTestCase {

    var repository: InMemoryNoteRepository!
    var embeddingService: EmbeddingService!
    var searchEngine: VectorSearchEngine!
    var noteService: NoteService!
    var viewModel: NoteViewModel!
    var testNote: Note!

    override func setUp() async throws {
        try await super.setUp()

        // Create dependencies
        repository = InMemoryNoteRepository()
        embeddingService = EmbeddingService()
        try await embeddingService.loadModel()
        searchEngine = VectorSearchEngine(embeddingService: embeddingService)
        noteService = NoteService(
            repository: repository,
            searchEngine: searchEngine,
            embeddingService: embeddingService
        )

        // Create a test note
        testNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0),
            content: "# Test Note\n\nThis is test content.",
            title: "Test Note",
            backlinks: [UUID(), UUID()],
            unknownFrontmatterFields: [:]
        )

        // Add test note through note service (automatic indexing)
        _ = try await noteService.create(note: testNote)
    }

    override func tearDown() async throws {
        viewModel = nil
        noteService = nil
        searchEngine = nil
        embeddingService = nil
        repository = nil
        testNote = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializeWithNoteId() async {
        // When
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)

        // Then
        XCTAssertEqual(viewModel.id, testNote.id, "ViewModel should store note ID")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading on init")
        XCTAssertNil(viewModel.error, "Should have no error on init")
    }

    // MARK: - Load Tests

    func testLoadPopulatesAllFields() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)

        // When
        await viewModel.load()

        // Then
        XCTAssertEqual(viewModel.id, testNote.id)
        XCTAssertEqual(viewModel.title, testNote.title)
        XCTAssertEqual(viewModel.content, testNote.content)
        XCTAssertEqual(viewModel.created, testNote.created)
        XCTAssertEqual(viewModel.device, testNote.device)
        XCTAssertEqual(viewModel.location?.latitude, testNote.location?.latitude)
        XCTAssertEqual(viewModel.location?.longitude, testNote.location?.longitude)
        XCTAssertEqual(viewModel.backlinks, Array(testNote.backlinks))
        XCTAssertNil(viewModel.error, "Should have no error after successful load")
    }

    func testLoadSetsIsLoadingCorrectly() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)

        // When/Then
        XCTAssertFalse(viewModel.isLoading, "Should not be loading before load()")

        // Start loading (we can't easily test the intermediate state due to async)
        await viewModel.load()

        XCTAssertFalse(viewModel.isLoading, "Should not be loading after load() completes")
    }

    func testLoadHandlesMissingNote() async {
        // Given
        let nonExistentId = UUID()
        viewModel = NoteViewModel(noteService: noteService, noteId: nonExistentId)

        // When
        await viewModel.load()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error for missing note")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after error")
    }

    func testLoadHandlesRepositoryError() async {
        // Given - Create a repository that will throw an error
        let failingRepository = FailingRepository()
        viewModel = NoteViewModel(repository: failingRepository, noteId: UUID())

        // When
        await viewModel.load()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error when repository fails")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after error")
    }

    // MARK: - Save Tests

    func testSaveUpdatesRepository() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        // When
        viewModel.updateTitle("Updated Title")
        viewModel.updateContent("Updated content")
        await viewModel.save()

        // Then
        let savedNote = try? await repository.read(id: testNote.id)
        XCTAssertNotNil(savedNote)
        XCTAssertEqual(savedNote?.title, "Updated Title")
        XCTAssertEqual(savedNote?.content, "Updated content")
        XCTAssertNil(viewModel.error, "Should have no error after successful save")
    }

    func testSaveValidatesEmptyTitle() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        // When
        viewModel.updateTitle("")
        await viewModel.save()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error for empty title")
    }

    func testSaveValidatesEmptyContent() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        // When
        viewModel.updateContent("")
        await viewModel.save()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error for empty content")
    }

    func testSaveValidatesWhitespaceOnlyTitle() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        // When
        viewModel.updateTitle("   ")
        await viewModel.save()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error for whitespace-only title")
    }

    func testSaveValidatesWhitespaceOnlyContent() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        // When
        viewModel.updateContent("   \n  ")
        await viewModel.save()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error for whitespace-only content")
    }

    func testSaveHandlesRepositoryError() async {
        // Given
        let failingRepository = FailingRepository()
        viewModel = NoteViewModel(repository: failingRepository, noteId: UUID())

        // When
        viewModel.updateTitle("Test")
        viewModel.updateContent("Test content")
        await viewModel.save()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error when repository fails")
    }

    // MARK: - Update Content Tests

    func testUpdateContentChangesContent() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()
        let originalContent = viewModel.content

        // When
        let newContent = "# New Content\n\nThis is updated."
        viewModel.updateContent(newContent)

        // Then
        XCTAssertNotEqual(viewModel.content, originalContent)
        XCTAssertEqual(viewModel.content, newContent)
    }

    func testUpdateContentClearsErrorWhenBothFieldsValid() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        // Set an error by trying to save with empty content
        viewModel.updateContent("")
        await viewModel.save()
        XCTAssertNotNil(viewModel.error, "Should have validation error")

        // When - Fix content (title is already valid from load)
        viewModel.updateContent("Valid content")

        // Then - Error should clear since both fields are now valid
        XCTAssertNil(viewModel.error, "Should clear error when both fields become valid")
    }

    // MARK: - Update Title Tests

    func testUpdateTitleChangesTitle() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()
        let originalTitle = viewModel.title

        // When
        let newTitle = "Updated Title"
        viewModel.updateTitle(newTitle)

        // Then
        XCTAssertNotEqual(viewModel.title, originalTitle)
        XCTAssertEqual(viewModel.title, newTitle)
    }

    func testUpdateTitleClearsErrorWhenBothFieldsValid() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        // Set an error by trying to save with empty title
        viewModel.updateTitle("")
        await viewModel.save()
        XCTAssertNotNil(viewModel.error, "Should have validation error")

        // When - Fix title (content is already valid from load)
        viewModel.updateTitle("Valid title")

        // Then - Error should clear since both fields are now valid
        XCTAssertNil(viewModel.error, "Should clear error when both fields become valid")
    }

    // MARK: - Error Handling Tests

    func testErrorIsPublished() async {
        // Given
        let nonExistentId = UUID()
        viewModel = NoteViewModel(noteService: noteService, noteId: nonExistentId)

        // When
        await viewModel.load()

        // Then
        XCTAssertNotNil(viewModel.error, "Error should be published")
    }

    func testSuccessfulSaveClearsError() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        // Create an error state
        viewModel.updateTitle("")
        await viewModel.save()
        XCTAssertNotNil(viewModel.error)

        // When - Fix the issue and save again
        viewModel.updateTitle("Valid Title")
        await viewModel.save()

        // Then
        XCTAssertNil(viewModel.error, "Should clear error after successful save")
    }

    // MARK: - Read-only Field Tests

    func testReadOnlyFieldsNotModified() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        let originalId = viewModel.id
        let originalCreated = viewModel.created
        let originalDevice = viewModel.device

        // When - Update editable fields
        viewModel.updateTitle("New Title")
        viewModel.updateContent("New Content")
        await viewModel.save()

        // Then - Read-only fields should remain unchanged
        XCTAssertEqual(viewModel.id, originalId, "ID should not change")
        XCTAssertEqual(viewModel.created, originalCreated, "Created date should not change")
        XCTAssertEqual(viewModel.device, originalDevice, "Device should not change")
    }

    // MARK: - Unknown Frontmatter Fields Tests

    func testPreservesUnknownFrontmatterFields() async {
        // Given
        var noteWithUnknownFields = testNote!
        noteWithUnknownFields.unknownFrontmatterFields = [
            "custom_field": AnyCodable(value: "custom_value"),
            "another_field": AnyCodable(value: 42)
        ]
        _ = try? await repository.update(note: noteWithUnknownFields)

        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)

        // When
        await viewModel.load()
        viewModel.updateTitle("Updated Title")
        await viewModel.save()

        // Then
        let savedNote = try? await repository.read(id: testNote.id)
        XCTAssertEqual(savedNote?.unknownFrontmatterFields.count, 2, "Should preserve unknown fields")
    }

    // MARK: - Create New Note Tests

    func testSaveCreatesNewNoteWhenNotLoaded() async {
        // Given
        let newNoteId = UUID()
        viewModel = NoteViewModel(noteService: noteService, noteId: newNoteId)
        viewModel.updateTitle("New Note")
        viewModel.updateContent("New note content")

        // When
        await viewModel.save()

        // Then
        let savedNote = try? await repository.read(id: newNoteId)
        XCTAssertNotNil(savedNote, "Should create new note")
        XCTAssertEqual(savedNote?.title, "New Note")
        XCTAssertEqual(savedNote?.content, "New note content")
        XCTAssertNil(viewModel.error, "Should have no error")
    }

    func testSaveUpdatesExistingNoteAfterLoad() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()

        // When - Update and save
        viewModel.updateTitle("Updated Title")
        await viewModel.save()

        // Then - Should update, not create duplicate
        let allNotes = try? await repository.list()
        let notesWithSameId = allNotes?.filter { $0.id == testNote.id }
        XCTAssertEqual(notesWithSameId?.count, 1, "Should update existing note, not create duplicate")
    }

    // MARK: - Error Clearing Tests

    func testUpdateContentDoesNotClearRepositoryError() async {
        // Given
        let failingRepository = FailingRepository()
        viewModel = NoteViewModel(repository: failingRepository, noteId: UUID())
        viewModel.updateTitle("Title")
        viewModel.updateContent("Content")
        await viewModel.save()
        XCTAssertNotNil(viewModel.error, "Should have repository error")

        // When - Update content
        viewModel.updateContent("New content")

        // Then - Repository error should NOT be cleared
        XCTAssertNotNil(viewModel.error, "Should not clear repository error")
    }

    func testUpdateTitleDoesNotClearRepositoryError() async {
        // Given
        let failingRepository = FailingRepository()
        viewModel = NoteViewModel(repository: failingRepository, noteId: UUID())
        viewModel.updateTitle("Title")
        viewModel.updateContent("Content")
        await viewModel.save()
        XCTAssertNotNil(viewModel.error, "Should have repository error")

        // When - Update title
        viewModel.updateTitle("New title")

        // Then - Repository error should NOT be cleared
        XCTAssertNotNil(viewModel.error, "Should not clear repository error")
    }

    func testUpdateClearsValidationErrorOnlyWhenBothFieldsValid() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()
        viewModel.updateTitle("")
        await viewModel.save()
        XCTAssertNotNil(viewModel.error, "Should have validation error")

        // When - Fix only content, not title
        viewModel.updateContent("Valid content")

        // Then - Error should NOT be cleared (title still empty)
        XCTAssertNotNil(viewModel.error, "Should not clear error when only one field is valid")

        // When - Fix title too
        viewModel.updateTitle("Valid title")

        // Then - Now error should be cleared
        XCTAssertNil(viewModel.error, "Should clear error when both fields are valid")
    }

    // MARK: - Loading State Tests

    func testLoadingStateIsClearedOnValidationFailure() async {
        // Given
        viewModel = NoteViewModel(noteService: noteService, noteId: testNote.id)
        await viewModel.load()
        viewModel.updateTitle("") // Make invalid

        // When
        await viewModel.save()

        // Then
        XCTAssertFalse(viewModel.isLoading, "Should clear loading state on validation failure")
        XCTAssertNotNil(viewModel.error, "Should have validation error")
    }
}

// MARK: - Mock Failing Repository

actor FailingRepository: NoteRepository {
    func create(note: Note) async throws -> Note {
        throw RepositoryError.storageError("Simulated failure")
    }

    func read(id: UUID) async throws -> Note? {
        throw RepositoryError.storageError("Simulated failure")
    }

    func update(note: Note) async throws -> Note {
        throw RepositoryError.storageError("Simulated failure")
    }

    func delete(id: UUID) async throws {
        throw RepositoryError.storageError("Simulated failure")
    }

    func list() async throws -> [Note] {
        throw RepositoryError.storageError("Simulated failure")
    }

    func search(query: String) async throws -> [Note] {
        throw RepositoryError.storageError("Simulated failure")
    }
}
