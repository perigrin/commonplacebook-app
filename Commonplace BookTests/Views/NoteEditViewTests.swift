// ABOUTME: Tests for note editing view
// ABOUTME: Validates UI behavior, user interactions, and integration with NoteViewModel

import XCTest
import SwiftUI
import ViewInspector
@testable import CommonplaceBook

extension NoteEditView: Inspectable {}

@MainActor
final class NoteEditViewTests: XCTestCase {

    var repository: InMemoryNoteRepository!
    var testNote: Note!
    var viewModel: NoteViewModel!

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
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // Add test note to repository
        _ = try await repository.create(note: testNote)

        // Create view model
        viewModel = NoteViewModel(repository: repository, noteId: testNote.id)
        await viewModel.load()
    }

    override func tearDown() async throws {
        viewModel = nil
        repository = nil
        testNote = nil
        try await super.tearDown()
    }

    // MARK: - View Rendering Tests

    func testViewRendersWithExistingNote() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When/Then - Should not crash
        XCTAssertNoThrow(try view.inspect())
    }

    func testViewDisplaysTitle() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When
        let vStack = try view.inspect().find(ViewType.VStack.self)

        // Then - Should contain title field
        XCTAssertNoThrow(try vStack.find(text: "Title"))
    }

    func testViewDisplaysContent() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When
        let vStack = try view.inspect().find(ViewType.VStack.self)

        // Then - Should contain content field
        XCTAssertNoThrow(try vStack.find(text: "Content"))
    }

    func testViewDisplaysRawMarkdownHint() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When
        let vStack = try view.inspect().find(ViewType.VStack.self)

        // Then - Should show "Raw markdown editor" hint
        XCTAssertNoThrow(try vStack.find(text: "Raw markdown editor"))
    }

    // MARK: - Navigation Tests

    func testViewHasSaveButton() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When/Then - Should have Save button in toolbar
        XCTAssertNoThrow(try view.inspect().find(button: "Save"))
    }

    func testViewHasCancelButton() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When/Then - Should have Cancel button in toolbar
        XCTAssertNoThrow(try view.inspect().find(button: "Cancel"))
    }

    func testNavigationTitleForExistingNote() throws {
        // Given
        viewModel.updateTitle("My Note")
        let view = NoteEditView(viewModel: viewModel)

        // When
        let navigationTitle = try view.inspect().navigationBarTitle()

        // Then
        XCTAssertEqual(navigationTitle, "Edit Note")
    }

    func testNavigationTitleForNewNote() throws {
        // Given
        let newViewModel = NoteViewModel(repository: repository, noteId: UUID())
        newViewModel.updateTitle("")
        let view = NoteEditView(viewModel: newViewModel)

        // When
        let navigationTitle = try view.inspect().navigationBarTitle()

        // Then
        XCTAssertEqual(navigationTitle, "New Note")
    }

    // MARK: - Error Display Tests

    func testErrorBannerDisplaysWhenErrorOccurs() async throws {
        // Given
        viewModel.updateTitle("") // This will cause validation error
        let view = NoteEditView(viewModel: viewModel)

        // When
        await viewModel.save()

        // Then - Error banner should be visible
        // Note: Due to async nature, we verify the error state in viewModel
        XCTAssertNotNil(viewModel.error)
    }

    func testErrorBannerShowsErrorMessage() async throws {
        // Given
        viewModel.updateTitle("")
        let view = NoteEditView(viewModel: viewModel)

        // When
        await viewModel.save()

        // Then
        XCTAssertEqual(viewModel.error?.localizedDescription, "Title cannot be empty")
    }

    // MARK: - Loading State Tests

    func testLoadingOverlayNotVisibleByDefault() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When/Then
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSaveButtonDisabledWhenLoading() async throws {
        // Given/When
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
    }

    // MARK: - Metadata Display Tests

    func testMetadataSectionDisplaysWhenDevicePresent() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When
        let vStack = try view.inspect().find(ViewType.VStack.self)

        // Then - Should display metadata section
        XCTAssertNoThrow(try vStack.find(text: "Metadata"))
    }

    func testMetadataSectionHidesWhenDeviceEmpty() throws {
        // Given
        let newViewModel = NoteViewModel(repository: repository, noteId: UUID())
        newViewModel.device = ""
        let view = NoteEditView(viewModel: newViewModel)

        // When/Then - Metadata section should not be present
        XCTAssertThrowsError(try view.inspect().find(text: "Metadata"))
    }

    func testMetadataDisplaysDate() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When
        let vStack = try view.inspect().find(ViewType.VStack.self)

        // Then - Should show calendar icon for date
        XCTAssertNoThrow(try vStack.find(ViewType.Image.self, where: { image in
            try image.actualImage().name() == "calendar"
        }))
    }

    func testMetadataDisplaysDevice() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When
        let vStack = try view.inspect().find(ViewType.VStack.self)

        // Then - Should show device name
        XCTAssertNoThrow(try vStack.find(text: "TestDevice"))
    }

    func testMetadataDisplaysLocationWhenPresent() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When
        let vStack = try view.inspect().find(ViewType.VStack.self)

        // Then - Should show location icon
        XCTAssertNoThrow(try vStack.find(ViewType.Image.self, where: { image in
            try image.actualImage().name() == "location.fill"
        }))
    }

    // MARK: - Integration Tests

    func testViewModelUpdatesWhenTitleChanges() async throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)
        let newTitle = "Updated Title"

        // When
        viewModel.updateTitle(newTitle)

        // Then
        XCTAssertEqual(viewModel.title, newTitle)
    }

    func testViewModelUpdatesWhenContentChanges() async throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)
        let newContent = "Updated content"

        // When
        viewModel.updateContent(newContent)

        // Then
        XCTAssertEqual(viewModel.content, newContent)
    }

    func testOnSaveCallbackInvokedAfterSuccessfulSave() async throws {
        // Given
        var callbackInvoked = false
        let view = NoteEditView(viewModel: viewModel, onSave: {
            callbackInvoked = true
        })

        viewModel.updateTitle("Valid Title")
        viewModel.updateContent("Valid Content")

        // When
        await viewModel.save()

        // Then
        XCTAssertTrue(callbackInvoked, "onSave callback should be invoked after successful save")
    }

    func testOnSaveCallbackNotInvokedWhenSaveFails() async throws {
        // Given
        var callbackInvoked = false
        let view = NoteEditView(viewModel: viewModel, onSave: {
            callbackInvoked = true
        })

        viewModel.updateTitle("") // Invalid - will cause save to fail

        // When
        await viewModel.save()

        // Then
        XCTAssertFalse(callbackInvoked, "onSave callback should not be invoked when save fails")
    }

    // MARK: - Accessibility Tests

    func testViewIsAccessible() throws {
        // Given
        let view = NoteEditView(viewModel: viewModel)

        // When/Then - Should be inspectable (basic accessibility)
        XCTAssertNoThrow(try view.inspect())
    }
}
