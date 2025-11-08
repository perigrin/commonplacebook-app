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

    // Change tracking
    private var lastSyncDate: Date?
    private var serverChangeToken: CKServerChangeToken?

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

        _isSyncing = true
        statusSubject.send(.syncing)

        // Setup CloudKit zone
        do {
            try await cloudKit.setupZone()
        } catch {
            print("Warning: Failed to setup CloudKit zone: \(error)")
            statusSubject.send(.error("Zone setup failed: \(error.localizedDescription)"))
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

        // Cancel ongoing operations
        syncTask?.cancel()
        backgroundSyncTask?.cancel()

        // Remove subscription
        do {
            try await cloudKit.deleteSubscription(withID: subscriptionID)
        } catch {
            print("Warning: Failed to remove CloudKit subscription: \(error)")
        }
    }

    func syncNow() async {
        do {
            statusSubject.send(.syncing)

            // Sync local changes to remote
            try await pushLocalChanges()

            // Sync remote changes to local
            try await pullRemoteChanges()

            // Update last sync timestamp
            lastSyncDate = Date()

            statusSubject.send(.idle)
        } catch {
            print("Sync error: \(error)")
            statusSubject.send(.error(error.localizedDescription))

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
            try await cloudKit.createSubscription(id: subscriptionID, recordType: recordType)
        } catch {
            print("Warning: Failed to create CloudKit subscription: \(error)")
        }
    }

    // MARK: - Push (Local to Remote)

    private func pushLocalChanges() async throws {
        // Get notes modified since last sync (change detection)
        let modifiedNotes: [Note]
        if let lastSync = lastSyncDate {
            modifiedNotes = try await repository.listModifiedSince(lastSync)
        } else {
            // First sync - upload all notes
            modifiedNotes = try await repository.list()
        }

        guard !modifiedNotes.isEmpty else {
            // No local changes - also check for deletes
            try await pushDeletes()
            return
        }

        // Upload modified notes to CloudKit
        var records: [CKRecord] = []
        for note in modifiedNotes {
            if let record = try await createCloudKitRecord(for: note) {
                records.append(record)
            }
        }

        if !records.isEmpty {
            try await cloudKit.saveRecords(records)
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
        // Get local note IDs
        let localIDs = try await repository.getAllNoteIDs()

        // Fetch all remote record IDs
        let remoteRecords = try await cloudKit.fetchRecords(ofType: recordType)
        let remoteIDs = Set(remoteRecords.compactMap { record -> UUID? in
            guard let idString = record["id"] as? String else { return nil }
            return UUID(uuidString: idString)
        })

        // Find notes that exist remotely but not locally (deleted)
        let deletedIDs = remoteIDs.subtracting(localIDs)

        guard !deletedIDs.isEmpty else { return }

        // Delete from CloudKit
        let recordIDsToDelete = deletedIDs.map { id in
            CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        }
        try await cloudKit.deleteRecords(withIDs: recordIDsToDelete)
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
              let id = UUID(uuidString: idString),
              let remoteCRDTData = record["crdt_data"] as? Data else {
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
        // Load LOCAL CRDT document from repository (CRITICAL FIX)
        guard let localCRDTData = try await repository.getCRDTData(for: id) else {
            // Local CRDT missing - use remote version
            let remoteNote = try await crdtService.readNote(docHandle: remoteDoc)
            _ = try await repository.update(note: remoteNote)
            return
        }

        // Load local CRDT document (preserves history)
        let localDoc = try await crdtService.load(data: localCRDTData)

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
                do {
                    // Wait for interval
                    try await Task.sleep(nanoseconds: UInt64(backgroundSyncInterval * 1_000_000_000))

                    // Perform sync if still active
                    guard let self = self else { break }
                    let stillSyncing = await self._isSyncing
                    if stillSyncing {
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
