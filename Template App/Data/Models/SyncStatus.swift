// ABOUTME: Sync status enumeration for iCloud sync state tracking
// ABOUTME: Represents the current state of synchronization operations

import Foundation

/// Status of iCloud sync operations
public enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case error(String)

    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing):
            return true
        case let (.error(lhsMsg), .error(rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
