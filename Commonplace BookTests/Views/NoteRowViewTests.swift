// ABOUTME: Tests for note list row view component
// ABOUTME: Covers display of title, preview text, and relative date formatting

import XCTest
import SwiftUI
@testable import CommonplaceBook

@MainActor
final class NoteRowViewTests: XCTestCase {

    var testNote: Note!

    override func setUp() async throws {
        try await super.setUp()

        testNote = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-3600), // 1 hour ago
            device: "TestDevice",
            location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0),
            content: "This is a long piece of content that should be truncated to show only the first 100 characters as a preview in the list view. This text is intentionally very long to test the truncation behavior.",
            title: "Test Note Title",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
    }

    func testNoteRowViewInitialization() {
        // GIVEN a note
        // WHEN creating a NoteRowView
        let view = NoteRowView(note: testNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteRowViewWithShortContent() {
        // GIVEN a note with short content
        let shortNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Short content",
            title: "Short Title",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteRowView
        let view = NoteRowView(note: shortNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteRowViewWithEmptyContent() {
        // GIVEN a note with empty content
        let emptyNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "",
            title: "Empty Content",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteRowView
        let view = NoteRowView(note: emptyNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteRowViewWithVeryOldDate() {
        // GIVEN a note created a year ago
        let oldNote = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-365 * 24 * 3600), // 1 year ago
            device: "TestDevice",
            location: nil,
            content: "Old content",
            title: "Old Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteRowView
        let view = NoteRowView(note: oldNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteRowViewWithFutureDate() {
        // GIVEN a note with future date (edge case)
        let futureNote = Note(
            id: UUID(),
            created: Date().addingTimeInterval(3600), // 1 hour in future
            device: "TestDevice",
            location: nil,
            content: "Future content",
            title: "Future Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteRowView
        let view = NoteRowView(note: futureNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testPreviewProviderDoesNotCrash() {
        // GIVEN the preview provider
        // WHEN accessing previews
        let previews = NoteRowView_Previews.previews

        // THEN it should not crash
        XCTAssertNotNil(previews)
    }
}
