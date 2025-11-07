// ABOUTME: Error types for NoteFileFormatter operations
// ABOUTME: Defines specific errors for serialization and deserialization failures

import Foundation

/// Errors that can occur during note file formatting operations
enum NoteFileFormatterError: Error, LocalizedError {
    case missingFrontmatter
    case invalidYAML(String)
    case invalidUUID(String)
    case invalidDate(String)
    case invalidLocation
    case missingRequiredField(String)
    case parsingError(String)

    var errorDescription: String? {
        switch self {
        case .missingFrontmatter:
            return "Missing or invalid frontmatter delimiters (---)"
        case .invalidYAML(let detail):
            return "Invalid YAML format: \(detail)"
        case .invalidUUID(let value):
            return "Invalid UUID: \(value)"
        case .invalidDate(let value):
            return "Invalid date format: \(value)"
        case .invalidLocation:
            return "Invalid location data"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .parsingError(let detail):
            return "Parsing error: \(detail)"
        }
    }
}
