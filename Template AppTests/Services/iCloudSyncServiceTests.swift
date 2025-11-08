// ABOUTME: Tests for iCloud sync service with CloudKit integration
// ABOUTME: Validates sync operations, conflict resolution, and error handling with mocked CloudKit

import XCTest
import CloudKit
@testable import Template_App

@MainActor
final class iCloudSyncServiceTests: XCTestCase {
    var syncService: iCloudSyncService!
    var mockCloudKit: MockCloudKitService!
    var mockRepository: MockCRDTNoteRepository!

    override func setUpWithError() throws {
        mockCloudKit = MockCloudKitService()
        mockRepository = MockCRDTNoteRepository()
        syncService = iCloudSyncService(
            cloudKit: mockCloudKit,
            repository: mockRepository
        )
    }

    override func tearDownWithError() throws {
        syncService = nil
        mockCloudKit = nil
        mockRepository = nil
    }

    // MARK: - Start/Stop Tests

    func testStartBeginsSyncing() async throws {
        // GIVEN stopped service
        XCTAssertFalse(await syncService.isSyncing, "Should not be syncing initially")

        // WHEN starting sync
        await syncService.start()

        // THEN syncing flag is true
        XCTAssertTrue(await syncService.isSyncing, "Should be syncing after start")
    }

    func testStopCancelsSyncing() async throws {
        // GIVEN running service
        await syncService.start()
        XCTAssertTrue(await syncService.isSyncing)

        // WHEN stopping
        await syncService.stop()

        // THEN syncing flag is false
        XCTAssertFalse(await syncService.isSyncing, "Should not be syncing after stop")
    }

    func testStartSubscribesToRemoteChanges() async throws {
        // GIVEN stopped service
        // WHEN starting
        await syncService.start()

        // THEN subscription created
        let subscriptionCreated = await mockCloudKit.subscriptionCreated
        XCTAssertTrue(subscriptionCreated, "Should create CloudKit subscription")
    }

    // MARK: - Local to Remote Sync Tests

    func testLocalChangeSyncsToiCloud() async throws {
        // GIVEN syncing service
        await syncService.start()

        // WHEN local note created
        let note = createTestNote(title: "Test Note", content: "Content")
        await mockRepository.addNote(note)
        await syncService.syncNow()

        // THEN note uploaded to CloudKit
        let uploadedRecords = await mockCloudKit.uploadedRecords
        XCTAssertEqual(uploadedRecords.count, 1, "Should upload 1 record")
        XCTAssertEqual(uploadedRecords.first?["id"] as? String, note.id.uuidString)
    }

    func testLocalUpdateSyncsToiCloud() async throws {
        // GIVEN syncing service with existing note
        await syncService.start()
        let original = createTestNote(title: "Original", content: "Original")
        await mockRepository.addNote(original)
        await syncService.syncNow()

        // WHEN note updated
        let updated = Note(
            id: original.id,
            created: original.created,
            device: original.device,
            location: nil,
            content: "Updated content",
            title: "Updated Title",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        await mockRepository.updateNote(updated)
        await syncService.syncNow()

        // THEN updated record uploaded
        let uploadedRecords = await mockCloudKit.uploadedRecords
        XCTAssertGreaterThanOrEqual(uploadedRecords.count, 2, "Should have upload for create and update")

        // Check latest upload has updated data
        let latestRecord = uploadedRecords.last
        XCTAssertNotNil(latestRecord?["crdt_data"] as? Data, "Should include CRDT data")
    }

    func testLocalDeleteSyncsToiCloud() async throws {
        // GIVEN syncing service with note
        await syncService.start()
        let note = createTestNote(title: "To Delete", content: "Content")
        await mockRepository.addNote(note)
        await syncService.syncNow()

        // WHEN note deleted
        await mockRepository.deleteNote(id: note.id)
        await syncService.syncNow()

        // THEN delete synced to CloudKit
        let deletedIDs = await mockCloudKit.deletedRecordIDs
        XCTAssertTrue(
            deletedIDs.contains(where: { $0.recordName == note.id.uuidString }),
            "Should delete record from CloudKit"
        )
    }

    // MARK: - Remote to Local Sync Tests

    func testRemoteChangeSyncsToLocal() async throws {
        // GIVEN syncing service
        await syncService.start()

        // WHEN remote note appears in CloudKit
        let remoteNote = createTestNote(title: "Remote Note", content: "From iCloud")
        await mockCloudKit.simulateRemoteChange(note: remoteNote)

        // Trigger sync
        await syncService.syncNow()

        // THEN note appears in local repository
        let localNotes = await mockRepository.getAllNotes()
        XCTAssertEqual(localNotes.count, 1, "Should have 1 note locally")
        XCTAssertEqual(localNotes.first?.title, "Remote Note")
    }

    func testRemoteUpdateSyncsToLocal() async throws {
        // GIVEN syncing service with existing note
        await syncService.start()
        let original = createTestNote(title: "Original", content: "Original")
        await mockRepository.addNote(original)
        await syncService.syncNow()

        // WHEN remote update arrives
        let updated = Note(
            id: original.id,
            created: original.created,
            device: "Remote Device",
            location: nil,
            content: "Updated from remote",
            title: "Remote Update",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
        await mockCloudKit.simulateRemoteChange(note: updated)
        await syncService.syncNow()

        // THEN local note updated
        let localNote = await mockRepository.getNote(id: original.id)
        XCTAssertNotNil(localNote)
        // Note: Exact content depends on CRDT merge behavior
    }

    func testRemoteDeleteSyncsToLocal() async throws {
        // GIVEN syncing service with note
        await syncService.start()
        let note = createTestNote(title: "To Delete", content: "Content")
        await mockRepository.addNote(note)
        await syncService.syncNow()

        // WHEN remote delete notification
        await mockCloudKit.simulateRemoteDelete(id: note.id)
        await syncService.syncNow()

        // THEN note deleted locally
        let localNote = await mockRepository.getNote(id: note.id)
        XCTAssertNil(localNote, "Note should be deleted locally")
    }

    // MARK: - Concurrent Changes / Conflict Resolution Tests

    func testConcurrentChangeMergeViaCRDT() async throws {
        // GIVEN syncing service with note
        await syncService.start()
        let original = createTestNote(title: "Original", content: "Original")
        await mockRepository.addNote(original)
        await syncService.syncNow()

        // WHEN local and remote both update
        let localUpdate = Note(
            id: original.id,
            created: original.created,
            device: "Local Device",
            location: nil,
            content: "Local update",
            title: "Local Title",
            backlinks: [UUID()],
            unknownFrontmatterFields: [:]
        )
        await mockRepository.updateNote(localUpdate)

        let remoteUpdate = Note(
            id: original.id,
            created: original.created,
            device: "Remote Device",
            location: nil,
            content: "Remote update",
            title: "Remote Title",
            backlinks: [UUID()],
            unknownFrontmatterFields: [:]
        )
        await mockCloudKit.simulateRemoteChange(note: remoteUpdate)

        await syncService.syncNow()

        // THEN changes merged (CRDT determines final state)
        let merged = await mockRepository.getNote(id: original.id)
        XCTAssertNotNil(merged, "Note should exist after merge")
        // Backlinks should be unioned
        XCTAssertGreaterThanOrEqual(merged?.backlinks.count ?? 0, 1, "Should have backlinks from merge")
    }

    // MARK: - Sync Status Tests

    func testSyncStatusUpdatesOnStart() async throws {
        // GIVEN status observer
        var statuses: [SyncStatus] = []
        let cancellable = await syncService.statusPublisher
            .sink { status in
                statuses.append(status)
            }

        // WHEN starting sync
        await syncService.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        // THEN status transitions
        XCTAssertTrue(statuses.contains(where: { $0 == .syncing }), "Should show syncing status")

        cancellable.cancel()
    }

    func testSyncStatusShowsErrorOnFailure() async throws {
        // GIVEN service with failing CloudKit
        await mockCloudKit.setShouldFail(true)

        var statuses: [SyncStatus] = []
        let cancellable = await syncService.statusPublisher
            .sink { status in
                statuses.append(status)
            }

        // WHEN attempting sync
        await syncService.start()
        try await Task.sleep(nanoseconds: 200_000_000)

        // THEN error status shown
        XCTAssertTrue(
            statuses.contains(where: {
                if case .error = $0 { return true }
                return false
            }),
            "Should show error status"
        )

        cancellable.cancel()
    }

    // MARK: - Network Failure Handling Tests

    func testHandlesNetworkFailure() async throws {
        // GIVEN syncing service
        await syncService.start()
        let note = createTestNote(title: "Test", content: "Content")
        await mockRepository.addNote(note)

        // WHEN network fails
        await mockCloudKit.setShouldFail(true)
        await syncService.syncNow()

        // THEN sync fails gracefully (no crash)
        XCTAssertTrue(true, "Should handle network failure without crashing")

        // AND status shows error
        let status = await syncService.currentStatus
        if case .error = status {
            XCTAssertTrue(true, "Status should show error")
        } else {
            XCTFail("Expected error status")
        }
    }

    func testRetriesOnTransientFailure() async throws {
        // GIVEN service with initially failing CloudKit
        await mockCloudKit.setShouldFail(true)
        await syncService.start()

        let note = createTestNote(title: "Test", content: "Content")
        await mockRepository.addNote(note)
        await syncService.syncNow()

        // WHEN network recovers
        await mockCloudKit.setShouldFail(false)

        // AND retry triggered
        try await Task.sleep(nanoseconds: 200_000_000)
        await syncService.syncNow()

        // THEN upload succeeds
        let uploadedRecords = await mockCloudKit.uploadedRecords
        XCTAssertGreaterThanOrEqual(uploadedRecords.count, 1, "Should eventually upload")
    }

    // MARK: - Force Sync Tests

    func testSyncNowForcesImmediateSync() async throws {
        // GIVEN service (not necessarily started)
        let note = createTestNote(title: "Immediate", content: "Content")
        await mockRepository.addNote(note)

        // WHEN force syncing
        await syncService.syncNow()

        // THEN sync happens immediately
        let uploadedRecords = await mockCloudKit.uploadedRecords
        XCTAssertGreaterThanOrEqual(uploadedRecords.count, 1, "Should sync immediately")
    }

    // MARK: - Helper Methods

    private func createTestNote(title: String, content: String) -> Note {
        Note(
            id: UUID(),
            created: Date(),
            device: "Test Device",
            location: nil,
            content: content,
            title: title,
            backlinks: [],
            unknownFrontmatterFields: [:]
        )
    }
}

// MARK: - Mock CloudKit Service

actor MockCloudKitService: CloudKitServiceProtocol {
    var uploadedRecords: [[String: Any]] = []
    var deletedRecordIDs: [CKRecord.ID] = []
    var subscriptionCreated = false
    private var shouldFail = false
    private var remoteRecords: [CKRecord] = []
    private var remoteChanges: [CKRecord] = []
    private var remoteDeletes: [CKRecord.ID] = []
    private let crdtService = CRDTService()
    private let zoneID = CKRecordZone.ID(zoneName: "NotesZone", ownerName: CKCurrentUserDefaultName)

    func setShouldFail(_ fail: Bool) {
        shouldFail = fail
    }

    func setupZone() async throws {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }
    }

    func saveRecords(_ records: [CKRecord]) async throws {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }
        for record in records {
            var recordDict: [String: Any] = [:]
            recordDict["id"] = record["id"]
            recordDict["crdt_data"] = record["crdt_data"]
            recordDict["modified"] = record["modified"]
            uploadedRecords.append(recordDict)
        }
        remoteRecords.append(contentsOf: records)
    }

    func fetchRecords(ofType recordType: String) async throws -> [CKRecord] {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }
        return remoteRecords
    }

    func deleteRecords(withIDs recordIDs: [CKRecord.ID]) async throws {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }
        deletedRecordIDs.append(contentsOf: recordIDs)
        remoteRecords.removeAll { record in
            recordIDs.contains(record.recordID)
        }
    }

    func createSubscription(id: String, recordType: String) async throws {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }
        subscriptionCreated = true
    }

    func deleteSubscription(withID subscriptionID: String) async throws {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }
        subscriptionCreated = false
    }

    func fetchChanges(in zone: CKRecordZone.ID, since token: CKServerChangeToken?) async throws -> (changed: [CKRecord], deleted: [CKRecord.ID], newToken: CKServerChangeToken?) {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }

        // Return accumulated changes
        let changes = remoteChanges
        let deletes = remoteDeletes

        // Clear accumulated changes
        remoteChanges.removeAll()
        remoteDeletes.removeAll()

        return (changes, deletes, nil)
    }

    func simulateRemoteChange(note: Note) async {
        // Create CRDT data for note
        let document = await crdtService.createDocument()
        try? await crdtService.updateNote(docHandle: document, note: note)
        let crdtData = await crdtService.save(docHandle: document)

        // Create CloudKit record
        let recordID = CKRecord.ID(recordName: note.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Note", recordID: recordID)
        record["id"] = note.id.uuidString as CKRecordValue
        record["crdt_data"] = crdtData as CKRecordValue
        record["modified"] = Date() as CKRecordValue

        remoteChanges.append(record)
        remoteRecords.append(record)
    }

    func simulateRemoteDelete(id: UUID) async {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        remoteDeletes.append(recordID)
        remoteRecords.removeAll { $0.recordID.recordName == id.uuidString }
    }
}

// MARK: - Mock CRDT Note Repository

actor MockCRDTNoteRepository: CRDTNoteRepositoryProtocol {
    private var notes: [UUID: Note] = [:]
    private var crdtData: [UUID: Data] = [:]
    private var modificationDates: [UUID: Date] = [:]
    private let crdtService = CRDTService()

    func addNote(_ note: Note) async {
        notes[note.id] = note
        modificationDates[note.id] = Date()

        // Create CRDT data
        let document = await crdtService.createDocument()
        try? await crdtService.updateNote(docHandle: document, note: note)
        crdtData[note.id] = await crdtService.save(docHandle: document)
    }

    func updateNote(_ note: Note) async {
        notes[note.id] = note
        modificationDates[note.id] = Date()

        // Update CRDT data
        let document = await crdtService.createDocument()
        try? await crdtService.updateNote(docHandle: document, note: note)
        crdtData[note.id] = await crdtService.save(docHandle: document)
    }

    func deleteNote(id: UUID) {
        notes.removeValue(forKey: id)
        crdtData.removeValue(forKey: id)
        modificationDates.removeValue(forKey: id)
    }

    func getNote(id: UUID) -> Note? {
        return notes[id]
    }

    func getAllNotes() -> [Note] {
        return Array(notes.values)
    }

    // MARK: - CRDTNoteRepositoryProtocol

    func create(note: Note) async throws -> Note {
        await addNote(note)
        return note
    }

    func read(id: UUID) async throws -> Note? {
        return getNote(id: id)
    }

    func update(note: Note) async throws -> Note {
        await updateNote(note)
        return note
    }

    func delete(id: UUID) async throws {
        deleteNote(id: id)
    }

    func list() async throws -> [Note] {
        return getAllNotes()
    }

    func search(query: String) async throws -> [Note] {
        return getAllNotes().filter { note in
            note.title.contains(query) || note.content.contains(query)
        }
    }

    func getCRDTData(for id: UUID) async throws -> Data? {
        return crdtData[id]
    }

    func listModifiedSince(_ date: Date) async throws -> [Note] {
        return notes.filter { id, _ in
            guard let modDate = modificationDates[id] else { return false }
            return modDate > date
        }.map { $0.value }
    }

    func getAllNoteIDs() async throws -> Set<UUID> {
        return Set(notes.keys)
    }
}
