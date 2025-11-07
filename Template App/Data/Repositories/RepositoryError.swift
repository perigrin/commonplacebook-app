// ABOUTME: Error types for repository operations
// ABOUTME: Defines specific errors for CRUD operations and data access failures

import Foundation

/// Errors that can occur during repository operations
enum RepositoryError: Error, LocalizedError {
    case noteNotFound(UUID)
    case duplicateNote(UUID)
    case storageError(String)
    case concurrencyError(String)

    var errorDescription: String? {
        switch self {
        case .noteNotFound(let id):
            return "Note not found with ID: \(id.uuidString)"
        case .duplicateNote(let id):
            return "Note already exists with ID: \(id.uuidString)"
        case .storageError(let detail):
            return "Storage error: \(detail)"
        case .concurrencyError(let detail):
            return "Concurrency error: \(detail)"
        }
    }
}
