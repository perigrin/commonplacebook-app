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

        // CloudKit limit is 400 records per operation - use 399 to stay safely under the boundary
        // Using exactly 400 can be rejected at the limit boundary
        let batchSize = 399
        let batches = stride(from: 0, to: records.count, by: batchSize).map {
            Array(records[$0..<min($0 + batchSize, records.count)])
        }

        // Process each batch sequentially
        for batch in batches {
            try await saveBatch(batch)
        }
    }

    private func saveBatch(_ records: [CKRecord]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.qualityOfService = .userInitiated

            // Add timeout configuration
            operation.configuration = CKOperation.Configuration()
            operation.configuration.timeoutIntervalForRequest = 30
            operation.configuration.timeoutIntervalForResource = 120

            // Handle partial errors - use lock for thread safety
            var saveErrors: [CKRecord.ID: Error] = [:]
            let lock = NSLock()

            operation.perRecordCompletionBlock = { record, error in
                if let error = error {
                    lock.lock()
                    saveErrors[record.recordID] = error
                    lock.unlock()
                }
            }

            operation.modifyRecordsCompletionBlock = { _, _, error in
                if let error = error {
                    // Check if all records failed or just some
                    lock.lock()
                    let errorCount = saveErrors.count
                    lock.unlock()

                    if errorCount == records.count {
                        // Total failure
                        continuation.resume(throwing: error)
                    } else if errorCount > 0 {
                        // Partial failure - log but continue
                        print("Warning: \(errorCount) records failed to save")
                        // Could track these for retry
                        continuation.resume()
                    } else {
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }

            database.add(operation)
        }
    }

    func fetchRecords(ofType recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        // Fetch with cursor-based pagination to get all records
        repeat {
            let (records, nextCursor) = try await fetchRecordsBatch(query: query, cursor: cursor)
            allRecords.append(contentsOf: records)
            cursor = nextCursor
        } while cursor != nil

        return allRecords
    }

    private func fetchRecordsBatch(query: CKQuery, cursor: CKQueryOperation.Cursor?) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([CKRecord], CKQueryOperation.Cursor?), Error>) in
            var batchRecords: [CKRecord] = []
            let lock = NSLock()

            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
                operation.zoneID = recordZone.zoneID
            }

            // Add timeout configuration
            operation.configuration = CKOperation.Configuration()
            operation.configuration.timeoutIntervalForRequest = 30
            operation.configuration.timeoutIntervalForResource = 120

            operation.recordFetchedBlock = { record in
                lock.lock()
                batchRecords.append(record)
                lock.unlock()
            }

            operation.queryCompletionBlock = { cursor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    lock.lock()
                    let records = batchRecords
                    lock.unlock()
                    continuation.resume(returning: (records, cursor))
                }
            }

            database.add(operation)
        }
    }

    func deleteRecords(withIDs recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }

        // CloudKit limit is 400 records per operation - use 399 to stay safely under the boundary
        // Using exactly 400 can be rejected at the limit boundary
        let batchSize = 399
        let batches = stride(from: 0, to: recordIDs.count, by: batchSize).map {
            Array(recordIDs[$0..<min($0 + batchSize, recordIDs.count)])
        }

        // Process each batch sequentially
        for batch in batches {
            try await deleteBatch(batch)
        }
    }

    private func deleteBatch(_ recordIDs: [CKRecord.ID]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
            operation.qualityOfService = .userInitiated

            // Add timeout configuration
            operation.configuration = CKOperation.Configuration()
            operation.configuration.timeoutIntervalForRequest = 30
            operation.configuration.timeoutIntervalForResource = 120

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

        // Use lock for thread safety
        let lock = NSLock()

        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = token

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zone], configurationsByRecordZoneID: [zone: configuration])

            // Add timeout configuration
            operation.configuration = CKOperation.Configuration()
            operation.configuration.timeoutIntervalForRequest = 30
            operation.configuration.timeoutIntervalForResource = 120

            operation.recordChangedBlock = { record in
                lock.lock()
                changedRecords.append(record)
                lock.unlock()
            }

            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                lock.lock()
                deletedRecordIDs.append(recordID)
                lock.unlock()
            }

            var fetchError: Error?

            operation.recordZoneFetchCompletionBlock = { zoneID, token, _, _, error in
                if let error = error {
                    fetchError = error
                } else {
                    lock.lock()
                    serverChangeToken = token
                    lock.unlock()
                }
            }

            operation.fetchRecordZoneChangesCompletionBlock = { error in
                // Only resume continuation here - not in zone fetch block
                if let error = error ?? fetchError {
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
