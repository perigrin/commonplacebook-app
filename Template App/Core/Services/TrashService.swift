// ABOUTME: Service managing soft-deleted notes and auto-purge functionality
// ABOUTME: Handles trash operations including restore, purge, and automatic cleanup

import Foundation

/// Service for managing deleted notes (trash)
@MainActor
class TrashService: ObservableObject {

    // MARK: - Published State

    /// Whether auto-purge is enabled
    @Published private(set) var isAutoPurgeEnabled: Bool = true

    // MARK: - Dependencies

    private let repository: NoteRepository
    private let userDefaults: UserDefaults

    // MARK: - Constants

    private let autoPurgeKey = "trashAutoPurgeAfter"
    private let defaultPurgeDuration: TimeInterval = 30 * 24 * 60 * 60  // 30 days

    // MARK: - Properties

    /// Duration after which deleted notes are automatically purged
    private(set) var autoPurgeAfter: TimeInterval

    // MARK: - Initialization

    init(repository: NoteRepository, userDefaults: UserDefaults = .standard) {
        self.repository = repository
        self.userDefaults = userDefaults

        // Load auto-purge duration from settings
        let savedDuration = userDefaults.double(forKey: autoPurgeKey)
        self.autoPurgeAfter = savedDuration > 0 ? savedDuration : defaultPurgeDuration
    }

    // MARK: - Trash Listing

    /// List all deleted notes
    /// - Returns: Array of soft-deleted notes
    func listTrashed() async throws -> [Note] {
        return try await repository.listTrashed()
    }

    // MARK: - Restore

    /// Restore a deleted note
    /// - Parameter id: The UUID of the note to restore
    func restore(id: UUID) async throws {
        try await repository.restore(id: id)
        Logger.info("Restored note \(id)", category: .general)
    }

    // MARK: - Purge

    /// Permanently delete a note
    /// - Parameter id: The UUID of the note to purge
    func purge(id: UUID) async throws {
        try await repository.purge(id: id)
        Logger.info("Purged note \(id)", category: .general)
    }

    /// Purge all deleted notes older than the auto-purge threshold
    /// - Returns: The number of notes purged
    @discardableResult
    func purgeOld() async throws -> Int {
        let trashedNotes = try await listTrashed()
        let now = Date()
        var purgeCount = 0

        for note in trashedNotes {
            guard let deletedAt = note.deletedAt else { continue }

            let age = now.timeIntervalSince(deletedAt)
            if age > autoPurgeAfter {
                try await purge(id: note.id)
                purgeCount += 1
            }
        }

        if purgeCount > 0 {
            Logger.info("Auto-purged \(purgeCount) old notes", category: .general)
        }

        return purgeCount
    }

    // MARK: - Settings

    /// Set the auto-purge duration
    /// - Parameter duration: Time interval after which notes are auto-purged
    func setAutoPurgeAfter(_ duration: TimeInterval) {
        autoPurgeAfter = duration
        userDefaults.set(duration, forKey: autoPurgeKey)
    }

    /// Common auto-purge durations
    enum PurgeDuration: TimeInterval, CaseIterable, Identifiable {
        case sevenDays = 604800  // 7 * 24 * 60 * 60
        case fourteenDays = 1209600  // 14 * 24 * 60 * 60
        case thirtyDays = 2592000  // 30 * 24 * 60 * 60
        case sixtyDays = 5184000  // 60 * 24 * 60 * 60

        var id: TimeInterval { rawValue }

        var displayName: String {
            switch self {
            case .sevenDays: return "7 days"
            case .fourteenDays: return "14 days"
            case .thirtyDays: return "30 days"
            case .sixtyDays: return "60 days"
            }
        }
    }

    /// Get the current purge duration as an enum case (if it matches)
    var currentPurgeDuration: PurgeDuration? {
        PurgeDuration.allCases.first { $0.rawValue == autoPurgeAfter }
    }

    // MARK: - Scheduled Purge

    /// Schedule automatic purge to run periodically
    /// Note: This should be called from app lifecycle hooks
    func scheduleAutoPurge() {
        Task {
            // Run purge immediately
            try? await purgeOld()

            // Schedule next purge (every 24 hours)
            // In production, use a more robust scheduling mechanism
            try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000)

            // Recursive call for continuous scheduling
            scheduleAutoPurge()
        }
    }
}
