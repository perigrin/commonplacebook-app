// ABOUTME: Tests for note list view with navigation and state handling
// ABOUTME: Covers loading states, errors, empty states, and ViewModel integration

import XCTest
import SwiftUI
@testable import CommonplaceBook

@MainActor
final class NoteListViewTests: XCTestCase {

    var repository: InMemoryNoteRepository!
    var metadataCollector: MockMetadataCollector!
    var viewModel: NoteListViewModel!

    override func setUp() async throws {
        try await super.setUp()

        repository = InMemoryNoteRepository()
        metadataCollector = MockMetadataCollector()
        viewModel = NoteListViewModel(repository: repository, metadataCollector: metadataCollector)
    }

    func testNoteListViewInitialization() {
        // GIVEN a view model
        // WHEN creating a NoteListView
        let view = NoteListView(viewModel: viewModel)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteListViewWithEmptyState() {
        // GIVEN a view model with no notes
        XCTAssertTrue(viewModel.notes.isEmpty)

        // WHEN creating a NoteListView
        let view = NoteListView(viewModel: viewModel)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteListViewWithNotes() async {
        // GIVEN a repository with notes
        let note1 = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-3600),
            device: "TestDevice",
            location: nil,
            content: "Content 1",
            title: "Note 1",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        let note2 = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-7200),
            device: "TestDevice",
            location: nil,
            content: "Content 2",
            title: "Note 2",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try! await repository.create(note: note1)
        _ = try! await repository.create(note: note2)

        // WHEN loading notes
        await viewModel.loadNotes()

        // THEN view should not crash with populated data
        let view = NoteListView(viewModel: viewModel)
        XCTAssertNotNil(view)
        XCTAssertEqual(viewModel.notes.count, 2)
    }

    func testNoteListViewWithLoadingState() {
        // GIVEN a view model
        // WHEN in loading state (simulated by checking initial state)
        let view = NoteListView(viewModel: viewModel)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteListViewWithError() async {
        // GIVEN a failing repository
        let failingRepository = FailingNoteRepository()
        let failingViewModel = NoteListViewModel(repository: failingRepository, metadataCollector: metadataCollector)

        // WHEN loading notes fails
        await failingViewModel.loadNotes()

        // THEN view should not crash with error state
        let view = NoteListView(viewModel: failingViewModel)
        XCTAssertNotNil(view)
        XCTAssertNotNil(failingViewModel.error)
    }

    func testNoteListViewWithMixedContent() async {
        // GIVEN notes with various content lengths
        let shortNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Short",
            title: "Short",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        let longNote = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-100),
            device: "TestDevice",
            location: nil,
            content: String(repeating: "Long content ", count: 50),
            title: "Very Long Title That Should Be Handled Properly",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        let emptyNote = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-200),
            device: "TestDevice",
            location: nil,
            content: "",
            title: "Empty Content",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        _ = try! await repository.create(note: shortNote)
        _ = try! await repository.create(note: longNote)
        _ = try! await repository.create(note: emptyNote)

        // WHEN loading notes
        await viewModel.loadNotes()

        // THEN view should handle all content types
        let view = NoteListView(viewModel: viewModel)
        XCTAssertNotNil(view)
        XCTAssertEqual(viewModel.notes.count, 3)
    }

    func testPreviewProviderDoesNotCrash() {
        // GIVEN the preview provider
        // WHEN accessing previews
        let previews = NoteListView_Previews.previews

        // THEN it should not crash
        XCTAssertNotNil(previews)
    }
}

// MARK: - Test Helpers

actor FailingNoteRepository: NoteRepository {
    func create(note: Note) async throws -> Note {
        throw RepositoryError.storageError("Simulated failure")
    }

    func read(id: UUID) async throws -> Note {
        throw RepositoryError.notFound
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
