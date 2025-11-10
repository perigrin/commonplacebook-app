// ABOUTME: Tests for NoteFileFormatter - markdown serialization/deserialization
// ABOUTME: Validates YAML frontmatter parsing and round-trip conversion

import Testing
import Foundation
@testable import Commonplace_Book

struct NoteFileFormatterTests {

    // MARK: - Serialization Tests

    @Test func serializeNoteWithAllFields() async throws {
        let location = Location(latitude: 37.7749, longitude: -122.4194, accuracy: 5.0)
        let backlink1 = UUID()
        let backlink2 = UUID()
        let note = Note(
            id: UUIDv7.generate(),
            created: Date(timeIntervalSince1970: 1699200000), // Fixed date for testing
            device: "iPhone 15 Pro",
            location: location,
            content: "# Test Note\n\nThis is a test note with footnotes[^1].\n\n[^1]: Footnote text.",
            title: "Test Note",
            backlinks: [backlink1, backlink2]
        )

        let formatter = NoteFileFormatter()
        let serialized = formatter.serialize(note: note)

        // Check frontmatter is present
        #expect(serialized.hasPrefix("---\n"))

        // Check YAML fields are present
        #expect(serialized.contains("id: \(note.id.uuidString)"))
        #expect(serialized.contains("device: iPhone 15 Pro"))
        #expect(serialized.contains("latitude: 37.7749"))
        #expect(serialized.contains("longitude: -122.4194"))
        #expect(serialized.contains("accuracy: 5.0"))
        #expect(serialized.contains("- \(backlink1.uuidString)"))
        #expect(serialized.contains("- \(backlink2.uuidString)"))

        // Check content is present
        #expect(serialized.contains("# Test Note"))
        #expect(serialized.contains("This is a test note"))
        #expect(serialized.contains("[^1]: Footnote text."))
    }

    @Test func serializeNoteWithMinimalFields() async throws {
        let note = Note(
            id: UUIDv7.generate(),
            created: Date(timeIntervalSince1970: 1699200000),
            device: "iPhone",
            location: nil,  // No location
            content: "Simple note content",
            title: "Simple",
            backlinks: []  // No backlinks
        )

        let formatter = NoteFileFormatter()
        let serialized = formatter.serialize(note: note)

        // Check frontmatter is present
        #expect(serialized.hasPrefix("---\n"))

        // Check required fields
        #expect(serialized.contains("id: \(note.id.uuidString)"))
        #expect(serialized.contains("device: iPhone"))

        // Location should not be present
        #expect(!serialized.contains("location:"))

        // Backlinks should not be present or empty
        // (depending on implementation, could be omitted or empty array)

        // Check content
        #expect(serialized.contains("Simple note content"))
    }

    // MARK: - Deserialization Tests

    @Test func deserializeCompleteNote() async throws {
        let id = UUID()
        let backlink1 = UUID()
        let backlink2 = UUID()

        let markdown = """
        ---
        id: \(id.uuidString)
        created: 2023-11-05T12:00:00Z
        device: iPhone 15 Pro
        location:
          latitude: 37.7749
          longitude: -122.4194
          accuracy: 5.0
        backlinks:
          - \(backlink1.uuidString)
          - \(backlink2.uuidString)
        ---

        # Test Note

        This is test content with footnotes[^1].

        [^1]: Footnote text.
        """

        let formatter = NoteFileFormatter()
        let note = try formatter.deserialize(content: markdown)

        #expect(note.id == id)
        #expect(note.device == "iPhone 15 Pro")
        #expect(note.location?.latitude == 37.7749)
        #expect(note.location?.longitude == -122.4194)
        #expect(note.location?.accuracy == 5.0)
        #expect(note.backlinks.contains(backlink1))
        #expect(note.backlinks.contains(backlink2))
        #expect(note.content.contains("# Test Note"))
        #expect(note.content.contains("This is test content"))
    }

    @Test func deserializeMinimalNote() async throws {
        let id = UUID()

        let markdown = """
        ---
        id: \(id.uuidString)
        created: 2023-11-05T12:00:00Z
        device: iPhone
        ---

        Simple note content.
        """

        let formatter = NoteFileFormatter()
        let note = try formatter.deserialize(content: markdown)

        #expect(note.id == id)
        #expect(note.device == "iPhone")
        #expect(note.location == nil)
        #expect(note.backlinks.isEmpty)
        #expect(note.content.contains("Simple note content"))
    }

    @Test func roundTripConversion() async throws {
        let originalNote = Note(
            id: UUIDv7.generate(),
            created: Date(timeIntervalSince1970: 1699200000),
            device: "iPad Air",
            location: Location(latitude: 40.7128, longitude: -74.0060, accuracy: 10.0),
            content: "# Round Trip Test\n\nContent with [links](https://example.com) and **bold**.",
            title: "Round Trip Test",
            backlinks: [UUID(), UUID()]
        )

        let formatter = NoteFileFormatter()

        // Serialize
        let serialized = formatter.serialize(note: originalNote)

        // Deserialize
        let deserializedNote = try formatter.deserialize(content: serialized)

        // Compare (should be equal)
        #expect(deserializedNote.id == originalNote.id)
        #expect(deserializedNote.device == originalNote.device)
        #expect(deserializedNote.location?.latitude == originalNote.location?.latitude)
        #expect(deserializedNote.location?.longitude == originalNote.location?.longitude)
        #expect(deserializedNote.location?.accuracy == originalNote.location?.accuracy)
        #expect(deserializedNote.backlinks == originalNote.backlinks)
        #expect(deserializedNote.content == originalNote.content)
        #expect(deserializedNote.title == originalNote.title)

        // Dates might have minor differences due to serialization precision
        let timeDifference = abs(deserializedNote.created.timeIntervalSince(originalNote.created))
        #expect(timeDifference < 1.0) // Within 1 second
    }

    @Test func handleMalformedYAML() async throws {
        let malformed = """
        ---
        id: not-a-valid-uuid
        created: invalid-date
        device: iPhone
        location:
          latitude: invalid
        ---

        Content
        """

        let formatter = NoteFileFormatter()

        // Should throw an error for malformed YAML
        #expect(throws: NoteFileFormatterError.self) {
            try formatter.deserialize(content: malformed)
        }
    }

    @Test func preserveUnknownFrontmatterFields() async throws {
        let id = UUID()

        let markdown = """
        ---
        id: \(id.uuidString)
        created: 2023-11-05T12:00:00Z
        device: iPhone
        custom_field: custom_value
        another_field: 123
        ---

        Content
        """

        let formatter = NoteFileFormatter()
        let note = try formatter.deserialize(content: markdown)

        // Should successfully deserialize, ignoring unknown fields
        #expect(note.id == id)
        #expect(note.device == "iPhone")

        // Re-serialize and check unknown fields are preserved
        let reserialized = formatter.serialize(note: note)

        // Unknown fields should be preserved
        #expect(reserialized.contains("custom_field: custom_value"))
        #expect(reserialized.contains("another_field: 123"))
    }

    @Test func handleFootnotesInMarkdown() async throws {
        let content = """
        # Note with Footnotes

        This is text with a footnote[^1].

        More text with another footnote[^2].

        [^1]: First footnote content.
        [^2]: Second footnote content.
        """

        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: content,
            title: "Note with Footnotes",
            backlinks: []
        )

        let formatter = NoteFileFormatter()
        let serialized = formatter.serialize(note: note)
        let deserialized = try formatter.deserialize(content: serialized)

        // Footnotes should be preserved
        #expect(deserialized.content.contains("[^1]"))
        #expect(deserialized.content.contains("[^2]"))
        #expect(deserialized.content.contains("[^1]: First footnote"))
        #expect(deserialized.content.contains("[^2]: Second footnote"))
    }

    @Test func handleEmptyBacklinks() async throws {
        let id = UUID()

        let markdown = """
        ---
        id: \(id.uuidString)
        created: 2023-11-05T12:00:00Z
        device: iPhone
        backlinks: []
        ---

        Content
        """

        let formatter = NoteFileFormatter()
        let note = try formatter.deserialize(content: markdown)

        #expect(note.backlinks.isEmpty)
    }

    @Test func handleMissingFrontmatterClosing() async throws {
        let malformed = """
        ---
        id: \(UUID().uuidString)
        created: 2023-11-05T12:00:00Z
        device: iPhone

        Content without closing frontmatter
        """

        let formatter = NoteFileFormatter()

        // Should throw an error for missing closing delimiter
        #expect(throws: NoteFileFormatterError.self) {
            try formatter.deserialize(content: malformed)
        }
    }
}
