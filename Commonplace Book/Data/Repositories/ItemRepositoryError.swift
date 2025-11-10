// ABOUTME: Error types for Item repository operations
// ABOUTME: Defines specific errors for Item CRUD operations and data access failures

import Foundation

/// Errors that can occur during Item repository operations
enum ItemRepositoryError: Error, LocalizedError {
    /// Entity not found
    case entityNotFound
    /// Failed to save
    case saveFailed(Error)
    /// Failed to update
    case updateFailed(Error)
    /// Failed to delete
    case deleteFailed(Error)
    /// Failed to fetch
    case fetchFailed(Error)
    /// Invalid entity
    case invalidEntity

    /// Descriptive error message
    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "The requested entity was not found."
        case .saveFailed(let error):
            return "Failed to save entity: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update entity: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete entity: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch entities: \(error.localizedDescription)"
        case .invalidEntity:
            return "The entity is invalid or has missing required properties."
        }
    }
}
