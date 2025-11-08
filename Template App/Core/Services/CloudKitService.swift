// ABOUTME: Production CloudKit service implementation with proper async API usage
// ABOUTME: Handles zone management, batch operations, and change tracking

import Foundation
import CloudKit

/// Production CloudKit service implementation
actor CloudKitService: CloudKitServiceProtocol {
    private let container: CKContainer
    private let database: CKDatabase
    private let recordZone: CKRecordZone

    init(container: CKContainer = .default()) {
        self.container = container
        self.database = container.privateCloudDatabase
        self.recordZone = CKRecordZone(zoneName: "NotesZone")
    }

    /// Ensure custom zone exists
    func setupZone() async throws {
        do {
            _ = try await database.save(recordZone)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, ignore
        }
    }

    // MARK: - CloudKitServiceProtocol

    func saveRecords(_ records: [CKRecord]) async throws {
        guard !records.isEmpty else { return }

        // Use batch operation for efficiency
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.qualityOfService = .userInitiated

            operation.modifyRecordsCompletionBlock = { _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }

            database.add(operation)
        }
    }

    func fetchRecords(ofType recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecord], Error>) in
            var allRecords: [CKRecord] = []

            let operation = CKQueryOperation(query: query)
            operation.zoneID = recordZone.zoneID
            operation.resultsLimit = CKQueryOperation.maximumResults

            operation.recordFetchedBlock = { record in
                allRecords.append(record)
            }

            operation.queryCompletionBlock = { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: allRecords)
                }
            }

            database.add(operation)
        }
    }

    func deleteRecords(withIDs recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
            operation.qualityOfService = .userInitiated

            operation.modifyRecordsCompletionBlock = { _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }

            database.add(operation)
        }
    }

    func createSubscription(id: String, recordType: String) async throws {
        let subscription = CKRecordZoneSubscription(zoneID: recordZone.zoneID, subscriptionID: id)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        _ = try await database.save(subscription)
    }

    func deleteSubscription(withID subscriptionID: String) async throws {
        _ = try await database.deleteSubscription(withID: subscriptionID)
    }

    func fetchChanges(in zone: CKRecordZone.ID, since token: CKServerChangeToken?) async throws -> (changed: [CKRecord], deleted: [CKRecord.ID], newToken: CKServerChangeToken?) {
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var serverChangeToken: CKServerChangeToken?

        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = token

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zone], configurationsByRecordZoneID: [zone: configuration])

            operation.recordChangedBlock = { record in
                changedRecords.append(record)
            }

            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deletedRecordIDs.append(recordID)
            }

            operation.recordZoneFetchCompletionBlock = { zoneID, token, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    serverChangeToken = token
                }
            }

            operation.fetchRecordZoneChangesCompletionBlock = { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }

            database.add(operation)
        }

        return (changedRecords, deletedRecordIDs, serverChangeToken)
    }
}
