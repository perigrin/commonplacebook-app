// ABOUTME: Serializes and deserializes notes to/from markdown with YAML frontmatter
// ABOUTME: Handles conversion between Note objects and file format with metadata preservation

import Foundation
import Yams

/// Formats notes as markdown files with YAML frontmatter
class NoteFileFormatter {

    private let frontmatterDelimiter = "---"
    private let dateFormatter: ISO8601DateFormatter

    init() {
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    /// Serialize a note to markdown string with YAML frontmatter
    /// - Parameter note: The note to serialize
    /// - Returns: Markdown string with YAML frontmatter
    func serialize(note: Note) -> String {
        var yaml = [String]()

        // Required fields
        yaml.append("id: \(note.id.uuidString)")
        yaml.append("created: \(dateFormatter.string(from: note.created))")
        yaml.append("device: \(note.device)")

        // Optional location
        if let location = note.location {
            yaml.append("location:")
            yaml.append("  latitude: \(location.latitude)")
            yaml.append("  longitude: \(location.longitude)")
            yaml.append("  accuracy: \(location.accuracy)")
        }

        // Optional backlinks
        if !note.backlinks.isEmpty {
            yaml.append("backlinks:")
            for backlink in note.backlinks {
                yaml.append("  - \(backlink.uuidString)")
            }
        }

        // Unknown frontmatter fields (preserve them)
        for (key, value) in note.unknownFrontmatterFields.sorted(by: { $0.key < $1.key }) {
            yaml.append("\(key): \(serializeValue(value.value))")
        }

        // Build final markdown
        var result = frontmatterDelimiter + "\n"
        result += yaml.joined(separator: "\n")
        result += "\n" + frontmatterDelimiter + "\n"
        result += "\n"
        result += note.content

        return result
    }

    /// Deserialize markdown string with YAML frontmatter to a note
    /// - Parameter content: The markdown content with frontmatter
    /// - Returns: Deserialized note
    /// - Throws: NoteFileFormatterError if parsing fails
    func deserialize(content: String) throws -> Note {
        // Split into frontmatter and content
        let components = try splitFrontmatter(content)

        // Parse YAML frontmatter
        let metadata = try parseYAML(components.frontmatter)

        // Extract required fields
        guard let idString = metadata["id"] as? String,
              let id = UUID(uuidString: idString) else {
            throw NoteFileFormatterError.invalidUUID(metadata["id"] as? String ?? "nil")
        }

        guard let createdString = metadata["created"] as? String,
              let created = dateFormatter.date(from: createdString) else {
            throw NoteFileFormatterError.invalidDate(metadata["created"] as? String ?? "nil")
        }

        guard let device = metadata["device"] as? String else {
            throw NoteFileFormatterError.missingRequiredField("device")
        }

        // Extract optional location
        var location: Location? = nil
        if let locationDict = metadata["location"] as? [String: Any],
           let latitude = locationDict["latitude"] as? Double,
           let longitude = locationDict["longitude"] as? Double,
           let accuracy = locationDict["accuracy"] as? Double {
            location = Location(latitude: latitude, longitude: longitude, accuracy: accuracy)
        }

        // Extract optional backlinks
        var backlinks: Set<UUID> = []
        if let backlinksArray = metadata["backlinks"] as? [String] {
            backlinks = Set(backlinksArray.compactMap { UUID(uuidString: $0) })
        }

        // Extract title from content (first # line or use first line)
        let title = extractTitle(from: components.content)

        // Capture unknown fields (fields that aren't in our model)
        let knownKeys: Set<String> = ["id", "created", "device", "location", "backlinks"]
        var unknownFields: [String: AnyCodable] = [:]
        for (key, value) in metadata {
            if !knownKeys.contains(key) {
                unknownFields[key] = AnyCodable(value)
            }
        }

        return Note(
            id: id,
            created: created,
            device: device,
            location: location,
            content: components.content,
            title: title,
            backlinks: backlinks,
            unknownFrontmatterFields: unknownFields
        )
    }

    // MARK: - Private Helpers

    /// Split content into frontmatter and markdown body
    private func splitFrontmatter(_ content: String) throws -> (frontmatter: String, content: String) {
        let lines = content.components(separatedBy: .newlines)

        guard lines.first == frontmatterDelimiter else {
            throw NoteFileFormatterError.missingFrontmatter
        }

        // Find the closing delimiter
        var frontmatterEndIndex: Int?
        for (index, line) in lines.enumerated() where index > 0 {
            if line == frontmatterDelimiter {
                frontmatterEndIndex = index
                break
            }
        }

        guard let endIndex = frontmatterEndIndex else {
            throw NoteFileFormatterError.missingFrontmatter
        }

        let frontmatterLines = Array(lines[1..<endIndex])
        let contentLines = Array(lines[(endIndex + 1)...])

        let frontmatter = frontmatterLines.joined(separator: "\n")
        let contentBody = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return (frontmatter, contentBody)
    }

    /// Parse YAML string into dictionary using Yams library
    /// Yams is a production-ready YAML 1.2 parser that handles all edge cases correctly
    private func parseYAML(_ yaml: String) throws -> [String: Any] {
        do {
            guard let parsed = try Yams.load(yaml: yaml) as? [String: Any] else {
                throw NoteFileFormatterError.invalidYAML("YAML did not parse to dictionary")
            }
            return parsed
        } catch let error as YamlError {
            throw NoteFileFormatterError.invalidYAML("Yams parsing error: \(error)")
        } catch {
            throw NoteFileFormatterError.parsingError("Unexpected YAML parsing error: \(error)")
        }
    }

    /// Serialize an Any value to YAML-compatible string
    private func serializeValue(_ value: Any) -> String {
        switch value {
        case let string as String:
            // Quote strings that contain special characters
            if string.contains(":") || string.contains("#") || string.contains("-") {
                return "\"\(string)\""
            }
            return string
        case let int as Int:
            return String(int)
        case let double as Double:
            return String(double)
        case let bool as Bool:
            return bool ? "true" : "false"
        case let array as [Any]:
            // Simple array serialization - for complex cases, Yams should be used
            return "[\(array.map { serializeValue($0) }.joined(separator: ", "))]"
        default:
            return String(describing: value)
        }
    }

    /// Extract title from markdown content
    private func extractTitle(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)

        // Look for first # header
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
        }

        // Fallback: use first non-empty line, max 50 chars
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return String(trimmed.prefix(50))
            }
        }

        return "Untitled"
    }
}
