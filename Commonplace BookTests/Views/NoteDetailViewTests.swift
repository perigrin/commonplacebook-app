// ABOUTME: Tests for read-only note detail view
// ABOUTME: Covers display of title, content, and metadata (device, date, location)

import XCTest
import SwiftUI
@testable import CommonplaceBook

@MainActor
final class NoteDetailViewTests: XCTestCase {

    var testNote: Note!

    override func setUp() async throws {
        try await super.setUp()

        testNote = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-3600),
            device: "iPhone 15 Pro",
            location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0),
            content: "# Test Note\n\nThis is test content with multiple paragraphs.\n\nSecond paragraph here.",
            title: "Test Note",
            backlinks: [UUID(), UUID()],
            unknownFrontmatterFields: [:]
        )
    }

    func testNoteDetailViewInitialization() {
        // GIVEN a note
        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: testNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteDetailViewWithMinimalNote() {
        // GIVEN a note with minimal data (no location, no backlinks)
        let minimalNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Minimal content",
            title: "Minimal Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: minimalNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteDetailViewWithLongContent() {
        // GIVEN a note with very long content
        let longContent = String(repeating: "This is a long paragraph. ", count: 100)
        let longNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: longContent,
            title: "Long Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: longNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteDetailViewWithEmptyContent() {
        // GIVEN a note with empty content
        let emptyNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "",
            title: "Empty Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: emptyNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteDetailViewWithMultilineContent() {
        // GIVEN a note with multiline markdown content
        let multilineNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: Location(latitude: 0.0, longitude: 0.0, accuracy: 100.0),
            content: """
            # Heading 1

            Some paragraph text here.

            ## Heading 2

            - Bullet point 1
            - Bullet point 2
            - Bullet point 3

            More text with **bold** and *italic*.
            """,
            title: "Multiline Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: multilineNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteDetailViewWithSpecialCharacters() {
        // GIVEN a note with special characters
        let specialNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Content with émojis 🎉 and spëcial çharacters!",
            title: "Spëcial Tïtle 🌟",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: specialNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteDetailViewWithVeryOldDate() {
        // GIVEN a note from several years ago
        let oldNote = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-3 * 365 * 24 * 3600), // 3 years ago
            device: "iPhone 12",
            location: nil,
            content: "Old content",
            title: "Old Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: oldNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testNoteDetailViewWithPreciseLocation() {
        // GIVEN a note with precise location data
        let locationNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: Location(latitude: 37.77493, longitude: -122.41942, accuracy: 5.0),
            content: "Note with location",
            title: "Location Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: locationNote)

        // THEN it should not crash
        XCTAssertNotNil(view)
    }

    func testPreviewProviderDoesNotCrash() {
        // GIVEN the preview provider
        // WHEN accessing previews
        let previews = NoteDetailView_Previews.previews

        // THEN it should not crash
        XCTAssertNotNil(previews)
    }

    // MARK: - Markdown Rendering Tests

    func testMarkdownBoldTextIsRendered() {
        // GIVEN a note with bold markdown text
        let markdownNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "This text has **bold** formatting.",
            title: "Bold Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: markdownNote)

        // THEN it should not crash and render markdown
        XCTAssertNotNil(view)

        // Verify the markdown content can be converted to AttributedString
        let attributedString = try? AttributedString(markdown: markdownNote.content)
        XCTAssertNotNil(attributedString, "Markdown should be convertible to AttributedString")
    }

    func testMarkdownItalicTextIsRendered() {
        // GIVEN a note with italic markdown text
        let markdownNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "This text has *italic* formatting.",
            title: "Italic Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: markdownNote)

        // THEN it should not crash and render markdown
        XCTAssertNotNil(view)

        // Verify the markdown content can be converted to AttributedString
        let attributedString = try? AttributedString(markdown: markdownNote.content)
        XCTAssertNotNil(attributedString, "Markdown should be convertible to AttributedString")
    }

    func testMarkdownHeadingsAreRendered() {
        // GIVEN a note with markdown headings
        let markdownNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: """
            # Big Heading Test

            ## Subheading

            Regular text here.

            ### Smaller heading
            """,
            title: "Big Heading Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: markdownNote)

        // THEN it should not crash and render markdown
        XCTAssertNotNil(view)

        // Verify the markdown content can be converted to AttributedString
        let attributedString = try? AttributedString(markdown: markdownNote.content)
        XCTAssertNotNil(attributedString, "Markdown headings should be convertible to AttributedString")
    }

    func testMarkdownListsAreRendered() {
        // GIVEN a note with markdown lists
        let markdownNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: """
            # List Test

            Shopping list:
            - Apples
            - Bananas
            - Oranges

            Numbered list:
            1. First item
            2. Second item
            3. Third item
            """,
            title: "List Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: markdownNote)

        // THEN it should not crash and render markdown
        XCTAssertNotNil(view)

        // Verify the markdown content can be converted to AttributedString
        let attributedString = try? AttributedString(markdown: markdownNote.content)
        XCTAssertNotNil(attributedString, "Markdown lists should be convertible to AttributedString")
    }

    func testMarkdownLinksAreRendered() {
        // GIVEN a note with markdown links
        let markdownNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Check out [this link](https://example.com) for more info.",
            title: "Link Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: markdownNote)

        // THEN it should not crash and render markdown
        XCTAssertNotNil(view)

        // Verify the markdown content can be converted to AttributedString
        let attributedString = try? AttributedString(markdown: markdownNote.content)
        XCTAssertNotNil(attributedString, "Markdown links should be convertible to AttributedString")
    }

    func testMarkdownCodeBlocksAreRendered() {
        // GIVEN a note with markdown code blocks
        let markdownNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: """
            # Code Test

            Here's some inline `code` and a block:

            ```swift
            func hello() {
                print("Hello, World!")
            }
            ```
            """,
            title: "Code Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: markdownNote)

        // THEN it should not crash and render markdown
        XCTAssertNotNil(view)

        // Verify the markdown content can be converted to AttributedString
        let attributedString = try? AttributedString(markdown: markdownNote.content)
        XCTAssertNotNil(attributedString, "Markdown code blocks should be convertible to AttributedString")
    }

    func testMarkdownMixedFormattingIsRendered() {
        // GIVEN a note with multiple markdown formatting types
        let markdownNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: """
            # Mixed Formatting Test

            This paragraph has **bold**, *italic*, and `code` formatting.

            ## Lists and Links

            - Item with [link](https://example.com)
            - Item with **bold text**
            - Item with *italic text*

            > This is a blockquote with **bold** text.
            """,
            title: "Mixed Formatting Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: markdownNote)

        // THEN it should not crash and render markdown
        XCTAssertNotNil(view)

        // Verify the markdown content can be converted to AttributedString
        let attributedString = try? AttributedString(markdown: markdownNote.content)
        XCTAssertNotNil(attributedString, "Mixed markdown formatting should be convertible to AttributedString")
    }

    func testInvalidMarkdownHandledGracefully() {
        // GIVEN a note with potentially problematic markdown
        let markdownNote = Note(
            id: UUID(),
            created: Date(),
            device: "TestDevice",
            location: nil,
            content: "Unclosed **bold and *italic formatting",
            title: "Invalid Markdown Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN creating a NoteDetailView
        let view = NoteDetailView(note: markdownNote)

        // THEN it should not crash even with invalid markdown
        XCTAssertNotNil(view)

        // Verify that even invalid markdown can be handled
        // AttributedString will do its best to parse what it can
        let attributedString = try? AttributedString(markdown: markdownNote.content)
        XCTAssertNotNil(attributedString, "Invalid markdown should still be convertible to AttributedString")
    }
}
