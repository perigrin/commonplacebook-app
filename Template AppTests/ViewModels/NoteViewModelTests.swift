// ABOUTME: Tests for note display/editing view model
// ABOUTME: Covers loading, saving, validation, and error handling with MVVM pattern

import XCTest
@testable import CommonplaceBook

@MainActor
final class NoteViewModelTests: XCTestCase {

    var repository: InMemoryNoteRepository!
    var viewModel: NoteViewModel!
    var testNote: Note!

    override func setUp() async throws {
        try await super.setUp()

        repository = InMemoryNoteRepository()

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

        // Add test note to repository
        _ = try await repository.create(note: testNote)
    }

    override func tearDown() async throws {
        viewModel = nil
        repository = nil
        testNote = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializeWithNoteId() async {
        // When
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)

        // Then
        XCTAssertEqual(viewModel.id, testNote.id, "ViewModel should store note ID")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading on init")
        XCTAssertNil(viewModel.error, "Should have no error on init")
    }

    // MARK: - Load Tests

    func testLoadPopulatesAllFields() async {
        // Given
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)

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
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)

        // When/Then
        XCTAssertFalse(viewModel.isLoading, "Should not be loading before load()")

        // Start loading (we can't easily test the intermediate state due to async)
        await viewModel.load()

        XCTAssertFalse(viewModel.isLoading, "Should not be loading after load() completes")
    }

    func testLoadHandlesMissingNote() async {
        // Given
        let nonExistentId = UUID()
        viewModel = NoteViewModel(repository: repository, noteId: nonExistentId)

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
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
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
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
        await viewModel.load()

        // When
        viewModel.updateTitle("")
        await viewModel.save()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error for empty title")
    }

    func testSaveValidatesEmptyContent() async {
        // Given
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
        await viewModel.load()

        // When
        viewModel.updateContent("")
        await viewModel.save()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error for empty content")
    }

    func testSaveValidatesWhitespaceOnlyTitle() async {
        // Given
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
        await viewModel.load()

        // When
        viewModel.updateTitle("   ")
        await viewModel.save()

        // Then
        XCTAssertNotNil(viewModel.error, "Should set error for whitespace-only title")
    }

    func testSaveValidatesWhitespaceOnlyContent() async {
        // Given
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
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
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
        await viewModel.load()
        let originalContent = viewModel.content

        // When
        let newContent = "# New Content\n\nThis is updated."
        viewModel.updateContent(newContent)

        // Then
        XCTAssertNotEqual(viewModel.content, originalContent)
        XCTAssertEqual(viewModel.content, newContent)
    }

    func testUpdateContentClearsError() async {
        // Given
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
        await viewModel.load()

        // Set an error by trying to save with empty content
        viewModel.updateContent("")
        await viewModel.save()
        XCTAssertNotNil(viewModel.error, "Should have validation error")

        // When
        viewModel.updateContent("Valid content")

        // Then
        XCTAssertNil(viewModel.error, "Should clear error when content becomes valid")
    }

    // MARK: - Update Title Tests

    func testUpdateTitleChangesTitle() async {
        // Given
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
        await viewModel.load()
        let originalTitle = viewModel.title

        // When
        let newTitle = "Updated Title"
        viewModel.updateTitle(newTitle)

        // Then
        XCTAssertNotEqual(viewModel.title, originalTitle)
        XCTAssertEqual(viewModel.title, newTitle)
    }

    func testUpdateTitleClearsError() async {
        // Given
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
        await viewModel.load()

        // Set an error by trying to save with empty title
        viewModel.updateTitle("")
        await viewModel.save()
        XCTAssertNotNil(viewModel.error, "Should have validation error")

        // When
        viewModel.updateTitle("Valid title")

        // Then
        XCTAssertNil(viewModel.error, "Should clear error when title becomes valid")
    }

    // MARK: - Error Handling Tests

    func testErrorIsPublished() async {
        // Given
        let nonExistentId = UUID()
        viewModel = NoteViewModel(repository: repository, noteId: nonExistentId)

        // When
        await viewModel.load()

        // Then
        XCTAssertNotNil(viewModel.error, "Error should be published")
    }

    func testSuccessfulSaveClearsError() async {
        // Given
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
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
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
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
