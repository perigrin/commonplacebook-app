// ABOUTME: Production iCloud sync service with proper CRDT lifecycle and change tracking
// ABOUTME: Bidirectional sync using CloudKit with conflict resolution via CRDT merge

import Foundation
import CloudKit
import Combine

/// iCloud sync service for cross-device CRDT synchronization
actor iCloudSyncService {

    // MARK: - Properties

    private let cloudKit: CloudKitServiceProtocol
    private let repository: CRDTNoteRepositoryProtocol
    private let crdtService: CRDTService

    private var syncTask: Task<Void, Never>?
    private var backgroundSyncTask: Task<Void, Never>?
    private var accountStatusObserver: NSObjectProtocol?

    // State machine for sync coordination (replaces NSLock)
    private enum SyncState {
        case idle
        case syncing(task: Task<Void, Never>)
    }
    private var syncState = SyncState.idle

    // Change tracking
    private var lastSyncDate: Date?
    private var _serverChangeToken: CKServerChangeToken?
    private var tokenLoaded = false

    private func loadTokenIfNeeded() {
        guard !tokenLoaded else { return }
        tokenLoaded = true

        guard let data = UserDefaults.standard.data(forKey: "icloud_sync_change_token") else {
            _serverChangeToken = nil
            return
        }

        do {
            _serverChangeToken = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: data
            )
        } catch {
            print("Corrupted change token, clearing: \(error)")
            UserDefaults.standard.removeObject(forKey: "icloud_sync_change_token")
            _serverChangeToken = nil
        }
    }

    private var serverChangeToken: CKServerChangeToken? {
        get {
            loadTokenIfNeeded()
            return _serverChangeToken
        }
        set {
            _serverChangeToken = newValue

            // Synchronous write - UserDefaults is thread-safe
            if let token = newValue {
                let data = try? NSKeyedArchiver.archivedData(
                    withRootObject: token,
                    requiringSecureCoding: true
                )
                UserDefaults.standard.set(data, forKey: "icloud_sync_change_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "icloud_sync_change_token")
            }
            UserDefaults.standard.synchronize() // Force immediate write
        }
    }

    // Retry management
    private var retryCount = 0
    private let maxRetries = 5

    // Status publishing (actor-safe)
    private let statusSubject = CurrentValueSubject<SyncStatus, Never>(.idle)
    private var _isSyncing = false

    // Configuration
    private let recordType = "Note"
    private let subscriptionID = "note-changes"
    private let backgroundSyncInterval: TimeInterval = 600 // 10 minutes
    private let zoneID = CKRecordZone.ID(zoneName: "NotesZone", ownerName: CKCurrentUserDefaultName)

    // MARK: - Public Interface

    var isSyncing: Bool {
        return _isSyncing
    }

    var currentStatus: SyncStatus {
        return statusSubject.value
    }

    nonisolated var statusPublisher: AnyPublisher<SyncStatus, Never> {
        return statusSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(
        cloudKit: CloudKitServiceProtocol,
        repository: CRDTNoteRepositoryProtocol
    ) {
        self.cloudKit = cloudKit
        self.repository = repository
        self.crdtService = CRDTService()
    }

    // MARK: - Lifecycle

    func start() async {
        guard !_isSyncing else { return }

        // Check iCloud authentication status
        do {
            let container = CKContainer.default()
            let accountStatus = try await container.accountStatus()

            guard accountStatus == .available else {
                let message: String
                switch accountStatus {
                case .noAccount:
                    message = "No iCloud account configured. Please sign in to iCloud in Settings."
                case .restricted:
                    message = "iCloud access is restricted."
                case .couldNotDetermine:
                    message = "Could not determine iCloud account status."
                case .temporarilyUnavailable:
                    message = "iCloud is temporarily unavailable."
                @unknown default:
                    message = "Unknown iCloud account status."
                }
                statusSubject.send(.error(message))
                throw iCloudSyncError.notAuthenticated(message)
            }
        } catch {
            print("Warning: iCloud authentication check failed: \(error)")
            statusSubject.send(.error("iCloud not available: \(error.localizedDescription)"))
            return
        }

        // Monitor iCloud account changes
        accountStatusObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleAccountChange()
            }
        }

        _isSyncing = true
        statusSubject.send(.syncing)

        // Setup CloudKit zone
        do {
            try await cloudKit.setupZone()
        } catch {
            print("Warning: Failed to setup CloudKit zone: \(error)")
            statusSubject.send(.error("Zone setup failed: \(error.localizedDescription)"))
            _isSyncing = false
            return
        }

        // Subscribe to remote changes
        await subscribeToRemoteChanges()

        // Perform initial sync
        await syncNow()

        // Start background sync timer
        startBackgroundSync()
    }

    func stop() async {
        _isSyncing = false
        statusSubject.send(.idle)

        // Wait for active sync using state machine
        if case .syncing(let task) = syncState {
            await task.value
        }
        syncState = .idle

        // Cancel ongoing operations
        syncTask?.cancel()
        backgroundSyncTask?.cancel()

        // Remove account observer
        if let observer = accountStatusObserver {
            NotificationCenter.default.removeObserver(observer)
            accountStatusObserver = nil
        }

        // Remove subscription
        do {
            try await cloudKit.deleteSubscription(withID: subscriptionID)
        } catch {
            print("Warning: Failed to remove CloudKit subscription: \(error)")
        }
    }

    private func handleAccountChange() async {
        print("iCloud account changed - re-verifying authentication")

        // Wait for active sync using state machine
        if case .syncing(let task) = syncState {
            print("Waiting for active sync to complete before handling account change")
            await task.value
        }

        do {
            let container = CKContainer.default()
            let accountStatus = try await container.accountStatus()

            if accountStatus == .available {
                // Re-setup sync
                await startBackgroundSync()
            } else {
                await stop()
                statusSubject.send(.error("iCloud account changed. Please restart sync."))
            }
        } catch {
            print("Failed to check account status: \(error)")
            await stop()
            statusSubject.send(.error("iCloud authentication lost"))
        }
    }

    func syncNow() async {
        switch syncState {
        case .idle:
            let task = Task {
                await performSyncWithRetry()
            }
            syncState = .syncing(task: task)
            await task.value
            syncState = .idle

        case .syncing(let existingTask):
            // Already syncing, wait for it
            await existingTask.value
        }
    }

    private func performSyncWithRetry() async {
        var attempt = 0
        while attempt < maxRetries {
            do {
                try await performSync()
                retryCount = 0
                return
            } catch {
                attempt += 1
                if attempt >= maxRetries {
                    print("Max retries reached, giving up")
                    statusSubject.send(.error("Sync failed after \(maxRetries) attempts"))
                    retryCount = 0
                    return
                }

                let delay = min(60.0, pow(2.0, Double(attempt)) * 5.0)
                print("Sync failed, retrying in \(delay)s (attempt \(attempt)/\(maxRetries))")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func performSync() async throws {
        statusSubject.send(.syncing)

        // Sync local changes to remote
        try await pushLocalChanges()

        // Sync remote changes to local
        try await pullRemoteChanges()

        // Update last sync timestamp
        lastSyncDate = Date()

        // Reset retry counter on success
        retryCount = 0
        statusSubject.send(.idle)
    }

    // MARK: - Remote Subscription

    private func subscribeToRemoteChanges() async {
        do {
            try await cloudKit.createSubscription(id: subscriptionID, recordType: recordType)
        } catch {
            print("Warning: Failed to create CloudKit subscription: \(error)")
        }
    }

    // MARK: - Push (Local to Remote)

    private func pushLocalChanges() async throws {
        guard let lastSync = lastSyncDate else {
            // First sync - use pagination to avoid memory exhaustion
            let batchSize = 100
            var offset = 0

            repeat {
                let batch = try await repository.list(limit: batchSize, offset: offset)
                guard !batch.isEmpty else { break }

                var recordsToSave: [CKRecord] = []

                for note in batch {
                    guard let crdtData = try await repository.getCRDTData(for: note.id) else {
                        continue
                    }

                    let recordID = CKRecord.ID(recordName: note.id.uuidString, zoneID: zoneID)
                    let record = CKRecord(recordType: recordType, recordID: recordID)
                    record["id"] = note.id.uuidString
                    record["crdt_data"] = crdtData
                    record["modified"] = note.modified as CKRecordValue
                    recordsToSave.append(record)
                }

                if !recordsToSave.isEmpty {
                    try await cloudKit.saveRecords(recordsToSave)
                }

                offset += batchSize
            } while true

            return
        }

        // Incremental sync - existing logic
        let modifiedNotes = try await repository.listModifiedSince(lastSync)

        var recordsToSave: [CKRecord] = []

        for note in modifiedNotes {
            guard let crdtData = try await repository.getCRDTData(for: note.id) else {
                continue
            }

            let recordID = CKRecord.ID(recordName: note.id.uuidString, zoneID: zoneID)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            record["id"] = note.id.uuidString
            record["crdt_data"] = crdtData
            record["modified"] = note.modified as CKRecordValue
            recordsToSave.append(record)
        }

        if !recordsToSave.isEmpty {
            try await cloudKit.saveRecords(recordsToSave)
        }

        // Handle deletes
        try await pushDeletes()
    }

    private func createCloudKitRecord(for note: Note) async throws -> CKRecord? {
        // Load existing CRDT data from repository (CRITICAL FIX)
        guard let crdtData = try await repository.getCRDTData(for: note.id) else {
            print("Warning: No CRDT data for note \(note.id)")
            return nil
        }

        // Create CloudKit record with CRDT data
        let recordID = CKRecord.ID(recordName: note.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        record["id"] = note.id.uuidString as CKRecordValue
        record["crdt_data"] = crdtData as CKRecordValue
        record["modified"] = Date() as CKRecordValue

        return record
    }

    private func pushDeletes() async throws {
        // Get deletions since last sync
        let deletedIDs: [UUID]
        if let lastSync = lastSyncDate {
            deletedIDs = try await repository.getDeletedSince(lastSync)
        } else {
            // First sync - no deletes to push
            return
        }

        guard !deletedIDs.isEmpty else { return }

        // Delete from CloudKit
        let recordIDsToDelete = deletedIDs.map { id in
            CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        }
        try await cloudKit.deleteRecords(withIDs: recordIDsToDelete)

        // Clear tombstones after successful sync
        for id in deletedIDs {
            try await repository.clearTombstone(id: id)
        }
    }

    // MARK: - Pull (Remote to Local)

    private func pullRemoteChanges() async throws {
        // Use change token for efficient incremental sync
        let changes = try await cloudKit.fetchChanges(
            in: zoneID,
            since: serverChangeToken
        )

        // Update change token
        serverChangeToken = changes.newToken

        // Process changed records
        for record in changes.changed {
            do {
                try await processRemoteRecord(record)
            } catch {
                print("Warning: Failed to process record \(record.recordID): \(error)")
            }
        }

        // Process deleted records
        for recordID in changes.deleted {
            if let id = UUID(uuidString: recordID.recordName) {
                try? await repository.delete(id: id)
            }
        }
    }

    private func processRemoteRecord(_ record: CKRecord) async throws {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString) else {
            throw iCloudSyncError.invalidRecord
        }

        // Validate CRDT data size and structure
        let maxCRDTSize = 10 * 1024 * 1024 // 10MB limit
        guard let remoteCRDTData = record["crdt_data"] as? Data,
              remoteCRDTData.count > 0,
              remoteCRDTData.count < maxCRDTSize else {
            print("Invalid CRDT data size: \(String(describing: (record["crdt_data"] as? Data)?.count))")
            throw iCloudSyncError.invalidRecord
        }

        // Load remote CRDT document
        let remoteDoc = try await crdtService.load(data: remoteCRDTData)

        // Check if note exists locally
        if let _ = try await repository.read(id: id) {
            // Note exists locally - merge CRDT documents
            try await mergeRemoteNote(id: id, remoteDoc: remoteDoc, remoteCRDTData: remoteCRDTData)
        } else {
            // New note - create locally with remote CRDT data
            let remoteNote = try await crdtService.readNote(docHandle: remoteDoc)
            _ = try await repository.create(note: remoteNote)
        }
    }

    private func mergeRemoteNote(id: UUID, remoteDoc: DocHandle, remoteCRDTData: Data) async throws {
        // Load LOCAL CRDT document from repository
        var localCRDTData = try await repository.getCRDTData(for: id)

        if localCRDTData == nil {
            print("WARNING: Missing local CRDT data for \(id). Attempting reconstruction.")

            if let localNote = try await repository.read(id: id) {
                let localDoc = await crdtService.createDocument()
                try await crdtService.updateNote(docHandle: localDoc, note: localNote)
                let reconstructedData = await crdtService.save(docHandle: localDoc)

                // Persist reconstructed data
                try await repository.saveCRDTData(for: id, data: reconstructedData)

                print("RECONSTRUCTED CRDT for \(id) - this may lose concurrent edits")
                // Continue with merge using reconstructed data
                localCRDTData = reconstructedData
            } else {
                // Check if this was deleted locally
                let deletedIDs = try await repository.getDeletedSince(Date.distantPast)
                if deletedIDs.contains(id) {
                    print("Note \(id) was deleted locally, skipping remote resurrection")
                    return
                }

                // Truly missing - use remote
                print("No local data at all for \(id), using remote version")
                let remoteNote = try await crdtService.readNote(docHandle: remoteDoc)
                _ = try await repository.create(note: remoteNote)
                try await repository.saveCRDTData(for: id, data: remoteCRDTData)
                return
            }
        }

        // Load local CRDT document (preserves history)
        let localDoc = try await crdtService.load(data: localCRDTData!)

        // Merge via CRDT (conflict-free)
        let merged = try await crdtService.merge(doc1: localDoc, doc2: remoteDoc)
        let mergedNote = try await crdtService.readNote(docHandle: merged)

        // Update local repository with merged result
        _ = try await repository.update(note: mergedNote)
    }

    // MARK: - Background Sync

    private func startBackgroundSync() {
        backgroundSyncTask?.cancel()

        backgroundSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                let interval = self.backgroundSyncInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                // Use syncIfActive which internally uses syncNow with retry
                await self.syncIfActive()
            }
        }
    }

    private func syncIfActive() async {
        guard _isSyncing else { return }
        await syncNow()
    }

    // MARK: - Error Handling

    enum iCloudSyncError: Error {
        case invalidRecord
        case syncFailed(String)
        case notAuthenticated(String)
    }

    // MARK: - Cleanup

    deinit {
        // Complete publisher to prevent memory leak
        statusSubject.send(completion: .finished)

        // Remove observer if still present
        if let observer = accountStatusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
