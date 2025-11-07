// ABOUTME: Tests for the Note model and related helpers
// ABOUTME: Validates UUID v7 generation, device name retrieval, and Note creation

import Testing
import Foundation
@testable import Template_App

struct NoteTests {

    // MARK: - UUID v7 Tests

    @Test func uuidV7Generation() async throws {
        let uuid1 = UUIDv7.generate()
        let uuid2 = UUIDv7.generate()

        // UUIDs should be different
        #expect(uuid1 != uuid2)

        // UUID v7 version bits should be set correctly (version 7)
        let versionBits = (uuid1.uuid.6 & 0xF0) >> 4
        #expect(versionBits == 7)
    }

    @Test func uuidV7TimestampOrdering() async throws {
        let uuid1 = UUIDv7.generate()
        // Small delay to ensure different timestamp
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        let uuid2 = UUIDv7.generate()

        // UUID v7s should be sortable by timestamp
        // Extract timestamp from first 48 bits
        let timestamp1 = UUIDv7.extractTimestamp(from: uuid1)
        let timestamp2 = UUIDv7.extractTimestamp(from: uuid2)

        #expect(timestamp2 > timestamp1)
    }

    @Test func uuidV7ThreadSafety() async throws {
        // Generate UUIDs concurrently from multiple threads
        await withTaskGroup(of: UUID.self) { group in
            // Launch 100 concurrent tasks
            for _ in 0..<100 {
                group.addTask {
                    return UUIDv7.generate()
                }
            }

            var uuids = Set<UUID>()
            for await uuid in group {
                uuids.insert(uuid)
            }

            // All UUIDs should be unique (no collisions)
            #expect(uuids.count == 100)
        }
    }

    // MARK: - Device Name Tests

    @Test func deviceNameRetrieval() async throws {
        let deviceName = DeviceInfo.getCurrentDeviceName()

        // Should return non-empty string
        #expect(!deviceName.isEmpty)

        // Should contain "iPhone", "iPad", or "Mac"
        let containsValidDevice = deviceName.contains("iPhone") ||
                                 deviceName.contains("iPad") ||
                                deviceName.contains("Mac")
        #expect(containsValidDevice)
    }

    // MARK: - Location Tests

    @Test func locationCreation() async throws {
        let location = Location(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 5.0
        )

        #expect(location.latitude == 37.7749)
        #expect(location.longitude == -122.4194)
        #expect(location.accuracy == 5.0)
    }

    @Test func locationValidation() async throws {
        // Valid latitude range: -90 to 90
        // Valid longitude range: -180 to 180
        // Valid accuracy: >= 0

        let validLocation = Location(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 5.0
        )
        #expect(validLocation.isValid)

        let invalidLatitude = Location(
            latitude: 91.0,  // Invalid: > 90
            longitude: 0.0,
            accuracy: 5.0
        )
        #expect(!invalidLatitude.isValid)

        let invalidLongitude = Location(
            latitude: 0.0,
            longitude: 181.0,  // Invalid: > 180
            accuracy: 5.0
        )
        #expect(!invalidLongitude.isValid)

        let invalidAccuracy = Location(
            latitude: 0.0,
            longitude: 0.0,
            accuracy: -1.0  // Invalid: < 0
        )
        #expect(!invalidAccuracy.isValid)
    }

    // MARK: - Note Tests

    @Test func noteCreationWithAllFields() async throws {
        let id = UUIDv7.generate()
        let created = Date()
        let device = "iPhone 15 Pro"
        let location = Location(latitude: 37.7749, longitude: -122.4194, accuracy: 5.0)
        let content = "# Test Note\n\nThis is a test note."
        let title = "Test Note"
        let backlinks: [UUID] = []

        let note = Note(
            id: id,
            created: created,
            device: device,
            location: location,
            content: content,
            title: title,
            backlinks: backlinks
        )

        #expect(note.id == id)
        #expect(note.created == created)
        #expect(note.device == device)
        #expect(note.location == location)
        #expect(note.content == content)
        #expect(note.title == title)
        #expect(note.backlinks == backlinks)
    }

    @Test func noteCreationWithMinimalFields() async throws {
        let note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone 15 Pro",
            location: nil,  // Optional
            content: "Minimal note",
            title: "Minimal",
            backlinks: []  // Can be empty
        )

        #expect(note.location == nil)
        #expect(note.backlinks.isEmpty)
    }

    @Test func noteBacklinksManipulation() async throws {
        var note = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Test",
            title: "Test",
            backlinks: []
        )

        // Add backlink
        let backlink1 = UUID()
        note.addBacklink(backlink1)
        #expect(note.backlinks.contains(backlink1))
        #expect(note.backlinks.count == 1)

        // Add another backlink
        let backlink2 = UUID()
        note.addBacklink(backlink2)
        #expect(note.backlinks.contains(backlink2))
        #expect(note.backlinks.count == 2)

        // Adding duplicate shouldn't increase count
        note.addBacklink(backlink1)
        #expect(note.backlinks.count == 2)

        // Remove backlink
        note.removeBacklink(backlink1)
        #expect(!note.backlinks.contains(backlink1))
        #expect(note.backlinks.count == 1)

        // Removing non-existent backlink should be safe
        note.removeBacklink(UUID())
        #expect(note.backlinks.count == 1)
    }

    @Test func noteValidation() async throws {
        // Valid note
        let validNote = Note(
            id: UUIDv7.generate(),
            created: Date(),
            device: "iPhone",
            location: nil,
            content: "Content",
            title: "Title",
            backlinks: []
        )

        #expect(validNote.isValid)

        // Invalid: empty title
        var invalidTitle = validNote
        invalidTitle.title = ""
        #expect(!invalidTitle.isValid)

        // Invalid: empty content
        var invalidContent = validNote
        invalidContent.content = ""
        #expect(!invalidContent.isValid)

        // Invalid: empty device
        var invalidDevice = validNote
        invalidDevice.device = ""
        #expect(!invalidDevice.isValid)

        // Invalid: invalid location
        var invalidLocation = validNote
        invalidLocation.location = Location(latitude: 91.0, longitude: 0.0, accuracy: 5.0)
        #expect(!invalidLocation.isValid)
    }

    @Test func noteHashableContract() async throws {
        // Create two identical notes
        let id = UUIDv7.generate()
        let created = Date()
        let note1 = Note(
            id: id,
            created: created,
            device: "iPhone",
            location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 5.0),
            content: "Test content",
            title: "Test",
            backlinks: [UUID()],
            unknownFrontmatterFields: ["custom": "value"]
        )

        let note2 = Note(
            id: id,
            created: created,
            device: "iPhone",
            location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 5.0),
            content: "Test content",
            title: "Test",
            backlinks: note1.backlinks,
            unknownFrontmatterFields: ["custom": "value"]
        )

        // Verify Hashable contract: equal objects must have equal hash values
        #expect(note1 == note2)
        #expect(note1.hashValue == note2.hashValue)

        // Verify they can be used in a Set correctly
        let noteSet: Set<Note> = [note1, note2]
        #expect(noteSet.count == 1) // Should only have one element since they're equal
    }
}
