// ABOUTME: iCloud sync service using CloudKit for cross-device CRDT synchronization
// ABOUTME: Handles bidirectional sync with conflict resolution via CRDT merge

import Foundation
import CloudKit
import Combine

/// iCloud sync service for cross-device CRDT synchronization
actor iCloudSyncService {

    // MARK: - Properties

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let repository: CRDTNoteRepository
    private let crdtService: CRDTService

    private var syncTask: Task<Void, Never>?
    private var backgroundSyncTask: Task<Void, Never>?
    private var subscription: CKSubscription?

    @Published private var status: SyncStatus = .idle
    private var _isSyncing = false

    // Configuration
    private let recordType = "Note"
    private let subscriptionID = "note-changes"
    private let backgroundSyncInterval: TimeInterval = 600 // 10 minutes

    // MARK: - Public Interface

    var isSyncing: Bool {
        return _isSyncing
    }

    var currentStatus: SyncStatus {
        return status
    }

    nonisolated var statusPublisher: Published<SyncStatus>.Publisher {
        return $status
    }

    // MARK: - Initialization

    init(
        cloudContainer: CKContainer = CKContainer.default(),
        repository: CRDTNoteRepository
    ) {
        self.container = cloudContainer
        self.privateDatabase = cloudContainer.privateCloudDatabase
        self.repository = repository
        self.crdtService = CRDTService()
    }

    init(
        cloudContainer: MockCloudKitContainer,
        repository: MockCRDTNoteRepository
    ) {
        // Mock initializer for testing
        fatalError("Mock initializer not yet implemented - use real initializer with real types")
    }

    // MARK: - Lifecycle

    func start() async {
        guard !_isSyncing else { return }

        _isSyncing = true
        status = .syncing

        // Subscribe to remote changes
        await subscribeToRemoteChanges()

        // Perform initial sync
        await syncNow()

        // Start background sync timer
        startBackgroundSync()
    }

    func stop() async {
        _isSyncing = false
        status = .idle

        // Cancel ongoing operations
        syncTask?.cancel()
        backgroundSyncTask?.cancel()

        // Remove subscription
        if let subscription = subscription {
            do {
                try await privateDatabase.deleteSubscription(withID: subscription.subscriptionID)
                self.subscription = nil
            } catch {
                print("Warning: Failed to remove CloudKit subscription: \(error)")
            }
        }
    }

    func syncNow() async {
        do {
            status = .syncing

            // Sync local changes to remote
            try await pushLocalChanges()

            // Sync remote changes to local
            try await pullRemoteChanges()

            status = .idle
        } catch {
            print("Sync error: \(error)")
            status = .error(error.localizedDescription)

            // Retry after delay
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if _isSyncing {
                await syncNow()
            }
        }
    }

    // MARK: - Remote Subscription

    private func subscribeToRemoteChanges() async {
        do {
            // Create subscription for note changes
            let subscription = CKQuerySubscription(
                recordType: recordType,
                predicate: NSPredicate(value: true),
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo

            self.subscription = try await privateDatabase.save(subscription)
        } catch {
            print("Warning: Failed to create CloudKit subscription: \(error)")
        }
    }

    // MARK: - Push (Local to Remote)

    private func pushLocalChanges() async throws {
        // Get all local notes
        let localNotes = try await repository.list()

        // Upload each note to CloudKit
        for note in localNotes {
            try await uploadNote(note)
        }
    }

    private func uploadNote(_ note: Note) async throws {
        // Create CRDT document for the note
        let document = await crdtService.createDocument()
        try await crdtService.updateNote(docHandle: document, note: note)
        let crdtData = await crdtService.save(docHandle: document)

        // Create CloudKit record
        let recordID = CKRecord.ID(recordName: note.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        record["id"] = note.id.uuidString as CKRecordValue
        record["crdt_data"] = crdtData as CKRecordValue
        record["modified"] = Date() as CKRecordValue

        // Upload to CloudKit
        try await privateDatabase.save(record)
    }

    // MARK: - Pull (Remote to Local)

    private func pullRemoteChanges() async throws {
        // Query all remote notes
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        let results = try await privateDatabase.records(matching: query)

        // Process each remote record
        for (recordID, result) in results.matchResults {
            do {
                let record = try result.get()
                try await processRemoteRecord(record)
            } catch {
                print("Warning: Failed to process record \(recordID): \(error)")
            }
        }
    }

    private func processRemoteRecord(_ record: CKRecord) async throws {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let crdtData = record["crdt_data"] as? Data else {
            throw iCloudSyncError.invalidRecord
        }

        // Load remote CRDT document
        let remoteDoc = try await crdtService.load(data: crdtData)
        let remoteNote = try await crdtService.readNote(docHandle: remoteDoc)

        // Check if note exists locally
        if let localNote = try await repository.read(id: id) {
            // Merge remote changes with local
            try await mergeRemoteNote(remoteNote, with: localNote)
        } else {
            // New note - create locally
            _ = try await repository.create(note: remoteNote)
        }
    }

    private func mergeRemoteNote(_ remote: Note, with local: Note) async throws {
        // Create CRDT documents for both
        let localDoc = await crdtService.createDocument()
        try await crdtService.updateNote(docHandle: localDoc, note: local)

        let remoteDoc = await crdtService.createDocument()
        try await crdtService.updateNote(docHandle: remoteDoc, note: remote)

        // Merge via CRDT
        let merged = try await crdtService.merge(doc1: localDoc, doc2: remoteDoc)
        let mergedNote = try await crdtService.readNote(docHandle: merged)

        // Update local repository
        _ = try await repository.update(note: mergedNote)
    }

    // MARK: - Background Sync

    private func startBackgroundSync() {
        backgroundSyncTask?.cancel()

        backgroundSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    // Wait for interval
                    try await Task.sleep(nanoseconds: UInt64(backgroundSyncInterval * 1_000_000_000))

                    // Perform sync if still active
                    if let self = self, await self._isSyncing {
                        await self.syncNow()
                    }
                } catch {
                    // Task cancelled or sleep interrupted
                    break
                }
            }
        }
    }

    // MARK: - Error Handling

    enum iCloudSyncError: Error {
        case invalidRecord
        case syncFailed(String)
    }
}
