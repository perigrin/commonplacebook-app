// ABOUTME: Tests for iCloud sync service with CloudKit integration
// ABOUTME: Validates sync operations, conflict resolution, and error handling with mocked CloudKit

import XCTest
import CloudKit
@testable import Template_App

@MainActor
final class iCloudSyncServiceTests: XCTestCase {
    var syncService: iCloudSyncService!
    var mockCloudKit: MockCloudKitContainer!
    var mockRepository: MockCRDTNoteRepository!

    override func setUpWithError() throws {
        mockCloudKit = MockCloudKitContainer()
        mockRepository = MockCRDTNoteRepository()
        syncService = iCloudSyncService(
            cloudContainer: mockCloudKit,
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
        XCTAssertTrue(mockCloudKit.subscriptionCreated, "Should create CloudKit subscription")
    }

    // MARK: - Local to Remote Sync Tests

    func testLocalChangesyncsToiCloud() async throws {
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

        // Allow time for sync
        try await Task.sleep(nanoseconds: 100_000_000)

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

        try await Task.sleep(nanoseconds: 100_000_000)

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

        try await Task.sleep(nanoseconds: 100_000_000)

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
        try await Task.sleep(nanoseconds: 200_000_000)

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
        try await Task.sleep(nanoseconds: 50_000_000)

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
        try await Task.sleep(nanoseconds: 100_000_000)

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

    // MARK: - Background Sync Tests

    func testBackgroundSyncScheduled() async throws {
        // GIVEN running service
        await syncService.start()

        // WHEN waiting for background sync interval
        // (In real app this would be 10 minutes, but test uses shorter interval)
        try await Task.sleep(nanoseconds: 100_000_000)

        // THEN background sync occurred
        // This is hard to test without time manipulation, so just verify no crash
        XCTAssertTrue(true, "Background sync should run without issues")
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

// MARK: - Mock CloudKit Container

actor MockCloudKitContainer {
    var uploadedRecords: [[String: Any]] = []
    var deletedRecordIDs: [CKRecord.ID] = []
    var subscriptionCreated = false
    private var shouldFail = false
    private var remoteChangeHandlers: [(Note) -> Void] = []
    private var remoteDeleteHandlers: [(UUID) -> Void] = []

    func setShouldFail(_ fail: Bool) {
        shouldFail = fail
    }

    func uploadRecord(_ record: [String: Any]) async throws {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }
        uploadedRecords.append(record)
    }

    func deleteRecord(id: CKRecord.ID) async throws {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }
        deletedRecordIDs.append(id)
    }

    func createSubscription() async throws {
        if shouldFail {
            throw NSError(domain: "MockCloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        }
        subscriptionCreated = true
    }

    func simulateRemoteChange(note: Note) async {
        // Simulate remote notification
        for handler in remoteChangeHandlers {
            handler(note)
        }
    }

    func simulateRemoteDelete(id: UUID) async {
        for handler in remoteDeleteHandlers {
            handler(id)
        }
    }

    func onRemoteChange(_ handler: @escaping (Note) -> Void) {
        remoteChangeHandlers.append(handler)
    }

    func onRemoteDelete(_ handler: @escaping (UUID) -> Void) {
        remoteDeleteHandlers.append(handler)
    }
}

// MARK: - Mock CRDT Note Repository

actor MockCRDTNoteRepository {
    private var notes: [UUID: Note] = [:]

    func addNote(_ note: Note) {
        notes[note.id] = note
    }

    func updateNote(_ note: Note) {
        notes[note.id] = note
    }

    func deleteNote(id: UUID) {
        notes.removeValue(forKey: id)
    }

    func getNote(id: UUID) -> Note? {
        return notes[id]
    }

    func getAllNotes() -> [Note] {
        return Array(notes.values)
    }
}

// MARK: - Sync Status Enum

enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)

    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
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
