// ABOUTME: Protocol abstraction for CloudKit operations enabling testability
// ABOUTME: Allows both real CloudKit and mock implementations for testing

import Foundation
import CloudKit

/// Protocol for CloudKit operations
protocol CloudKitServiceProtocol: Actor {
    /// Setup CloudKit zone for notes
    func setupZone() async throws

    /// Save records to CloudKit
    func saveRecords(_ records: [CKRecord]) async throws

    /// Fetch all records of a given type
    func fetchRecords(ofType recordType: String) async throws -> [CKRecord]

    /// Delete records by ID
    func deleteRecords(withIDs recordIDs: [CKRecord.ID]) async throws

    /// Create or update subscription
    func createSubscription(id: String, recordType: String) async throws

    /// Delete subscription
    func deleteSubscription(withID subscriptionID: String) async throws

    /// Fetch changes using change token
    func fetchChanges(in zone: CKRecordZone.ID, since token: CKServerChangeToken?) async throws -> (changed: [CKRecord], deleted: [CKRecord.ID], newToken: CKServerChangeToken?)
}

/// Protocol for note repository CRDT operations
protocol CRDTNoteRepositoryProtocol: Actor {
    /// Create a new note
    func create(note: Note) async throws -> Note

    /// Read a note by ID
    func read(id: UUID) async throws -> Note?

    /// Update an existing note
    func update(note: Note) async throws -> Note

    /// Delete a note
    func delete(id: UUID) async throws

    /// List all notes
    func list() async throws -> [Note]

    /// Get CRDT data for a note (for syncing)
    func getCRDTData(for id: UUID) async throws -> Data?

    /// List notes modified since a date
    func listModifiedSince(_ date: Date) async throws -> [Note]

    /// Get all note IDs (for detecting deletes)
    func getAllNoteIDs() async throws -> Set<UUID>

    /// Track deletion for sync
    func trackDeletion(id: UUID) throws

    /// Get IDs deleted since a date
    func getDeletedSince(_ date: Date) throws -> [UUID]

    /// Clear tombstone after successful sync
    func clearTombstone(id: UUID) throws
}
