// ABOUTME: Tests for UUIDv7 timestamp-ordered identifier generation
// ABOUTME: Validates uniqueness, timestamp extraction, sorting, and thread safety

import XCTest
@testable import Commonplace_Book

final class UUIDv7Tests: XCTestCase {

    // MARK: - Generation Tests

    func testGenerateCreatesValidUUID() {
        // WHEN generating a UUID v7
        let uuid = UUIDv7.generate()

        // THEN should return a valid UUID
        XCTAssertNotNil(uuid)
        XCTAssertNotEqual(uuid, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    func testGenerateCreatesUniqueUUIDs() {
        // WHEN generating multiple UUIDs
        var uuids = Set<UUID>()
        for _ in 0..<1000 {
            uuids.insert(UUIDv7.generate())
        }

        // THEN all should be unique
        XCTAssertEqual(uuids.count, 1000, "All generated UUIDs should be unique")
    }

    func testGenerateAtTimestampCreatesUUIDWithSpecifiedTime() {
        // GIVEN a specific timestamp
        let timestamp = Date(timeIntervalSince1970: 1609459200.0).timeIntervalSince1970 // Jan 1, 2021

        // WHEN generating UUID at that timestamp
        let uuid = UUIDv7.generate(at: timestamp)

        // THEN extracted timestamp should match (within millisecond precision)
        let extractedTimestamp = UUIDv7.extractTimestamp(from: uuid)
        XCTAssertEqual(extractedTimestamp, timestamp, accuracy: 0.001,
                      "Extracted timestamp should match original within 1ms")
    }

    func testGenerateAtZeroTimestamp() {
        // GIVEN timestamp of 0 (Unix epoch)
        let timestamp: TimeInterval = 0

        // WHEN generating UUID
        let uuid = UUIDv7.generate(at: timestamp)

        // THEN should handle gracefully
        let extractedTimestamp = UUIDv7.extractTimestamp(from: uuid)
        XCTAssertEqual(extractedTimestamp, 0, accuracy: 0.001)
    }

    func testGenerateAtFutureTimestamp() {
        // GIVEN a future timestamp (year 2100)
        let futureDate = Date(timeIntervalSince1970: 4102444800.0)
        let timestamp = futureDate.timeIntervalSince1970

        // WHEN generating UUID
        let uuid = UUIDv7.generate(at: timestamp)

        // THEN should handle future dates
        let extractedTimestamp = UUIDv7.extractTimestamp(from: uuid)
        XCTAssertEqual(extractedTimestamp, timestamp, accuracy: 0.001)
    }

    // MARK: - Version and Variant Tests

    func testGeneratedUUIDHasCorrectVersion() {
        // WHEN generating a UUID v7
        let uuid = UUIDv7.generate()
        let uuidString = uuid.uuidString

        // THEN version bits should be 7 (0111)
        // Version is in the 13th character (after 3rd hyphen)
        // Format: xxxxxxxx-xxxx-Vxxx-xxxx-xxxxxxxxxxxx
        let versionIndex = uuidString.index(uuidString.startIndex, offsetBy: 14)
        let versionChar = uuidString[versionIndex]
        XCTAssertEqual(versionChar, "7", "UUID should have version 7")
    }

    func testGeneratedUUIDHasCorrectVariant() {
        // WHEN generating a UUID v7
        let uuid = UUIDv7.generate()
        let bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }

        // THEN variant bits should be 10xxxxxx (0x80-0xBF)
        let variantByte = bytes[8]
        XCTAssertTrue((variantByte & 0xC0) == 0x80,
                     "Variant should be 10xxxxxx, got: \(String(format: "%02X", variantByte))")
    }

    // MARK: - Timestamp Extraction Tests

    func testExtractTimestampReturnsCorrectValue() {
        // GIVEN known timestamps
        let testTimestamps: [TimeInterval] = [
            0,                                    // Unix epoch
            946684800.0,                          // Jan 1, 2000
            1609459200.0,                         // Jan 1, 2021
            Date().timeIntervalSince1970,         // Now
            Date().timeIntervalSince1970 + 3600   // 1 hour from now
        ]

        for timestamp in testTimestamps {
            // WHEN generating and extracting
            let uuid = UUIDv7.generate(at: timestamp)
            let extracted = UUIDv7.extractTimestamp(from: uuid)

            // THEN should match within millisecond precision
            XCTAssertEqual(extracted, timestamp, accuracy: 0.001,
                          "Failed for timestamp: \(timestamp)")
        }
    }

    func testExtractTimestampFromRegularUUIDv4() {
        // GIVEN a regular UUID v4
        let regularUUID = UUID()

        // WHEN extracting timestamp
        let timestamp = UUIDv7.extractTimestamp(from: regularUUID)

        // THEN should return a value (though it won't be meaningful)
        // This test documents that extraction doesn't crash on non-v7 UUIDs
        XCTAssertGreaterThanOrEqual(timestamp, 0, "Should not crash on regular UUID")
    }

    // MARK: - Sorting Tests

    func testUUIDsSortByGenerationTime() {
        // GIVEN UUIDs generated at different times
        let uuid1 = UUIDv7.generate(at: 1000.0)
        let uuid2 = UUIDv7.generate(at: 2000.0)
        let uuid3 = UUIDv7.generate(at: 3000.0)

        let unsorted = [uuid3, uuid1, uuid2]

        // WHEN sorting
        let sorted = unsorted.sorted { uuid1, uuid2 in
            UUIDv7.extractTimestamp(from: uuid1) < UUIDv7.extractTimestamp(from: uuid2)
        }

        // THEN should be in timestamp order
        XCTAssertEqual(sorted[0], uuid1)
        XCTAssertEqual(sorted[1], uuid2)
        XCTAssertEqual(sorted[2], uuid3)
    }

    func testUUIDsGeneratedInSequenceAreSortable() {
        // GIVEN UUIDs generated in sequence
        var uuids: [UUID] = []
        for _ in 0..<100 {
            uuids.append(UUIDv7.generate())
            // Small delay to ensure timestamp difference
            Thread.sleep(forTimeInterval: 0.001)
        }

        // WHEN extracting timestamps
        let timestamps = uuids.map { UUIDv7.extractTimestamp(from: $0) }

        // THEN timestamps should be non-decreasing
        for i in 1..<timestamps.count {
            XCTAssertGreaterThanOrEqual(timestamps[i], timestamps[i-1],
                                       "Timestamps should be non-decreasing")
        }
    }

    func testUUIDsGeneratedSimultaneouslyHaveSameTimestamp() {
        // GIVEN a specific timestamp
        let timestamp: TimeInterval = 1609459200.0

        // WHEN generating multiple UUIDs at the same time
        let uuid1 = UUIDv7.generate(at: timestamp)
        let uuid2 = UUIDv7.generate(at: timestamp)
        let uuid3 = UUIDv7.generate(at: timestamp)

        // THEN all should have the same timestamp
        let ts1 = UUIDv7.extractTimestamp(from: uuid1)
        let ts2 = UUIDv7.extractTimestamp(from: uuid2)
        let ts3 = UUIDv7.extractTimestamp(from: uuid3)

        XCTAssertEqual(ts1, ts2, accuracy: 0.001)
        XCTAssertEqual(ts2, ts3, accuracy: 0.001)
    }

    func testUUIDsWithSameTimestampAreDifferent() {
        // GIVEN same timestamp
        let timestamp: TimeInterval = 1609459200.0

        // WHEN generating multiple UUIDs
        let uuid1 = UUIDv7.generate(at: timestamp)
        let uuid2 = UUIDv7.generate(at: timestamp)

        // THEN UUIDs should be different (random bits differ)
        XCTAssertNotEqual(uuid1, uuid2,
                         "UUIDs with same timestamp should differ in random bits")
    }

    // MARK: - Collision Resistance Tests

    func testNoCollisionsInRapidGeneration() {
        // GIVEN rapid UUID generation
        var uuids = Set<UUID>()
        let count = 10000

        // WHEN generating many UUIDs quickly
        for _ in 0..<count {
            uuids.insert(UUIDv7.generate())
        }

        // THEN no collisions should occur
        XCTAssertEqual(uuids.count, count,
                      "Should generate \(count) unique UUIDs without collisions")
    }

    func testNoCollisionsWithIdenticalTimestamps() {
        // GIVEN same timestamp
        let timestamp: TimeInterval = 1609459200.0
        var uuids = Set<UUID>()
        let count = 1000

        // WHEN generating many UUIDs with same timestamp
        for _ in 0..<count {
            uuids.insert(UUIDv7.generate(at: timestamp))
        }

        // THEN random bits should prevent collisions
        XCTAssertEqual(uuids.count, count,
                      "Should generate \(count) unique UUIDs even with same timestamp")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentGenerationIsSafe() {
        // GIVEN concurrent UUID generation
        let expectation = XCTestExpectation(description: "Concurrent generation completes")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        var uuids: [UUID] = []
        let lock = NSLock()

        // WHEN generating UUIDs from multiple threads
        for _ in 0..<100 {
            group.enter()
            queue.async {
                let uuid = UUIDv7.generate()
                lock.lock()
                uuids.append(uuid)
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all should be unique (no race condition collisions)
        let uniqueUUIDs = Set(uuids)
        XCTAssertEqual(uniqueUUIDs.count, 100,
                      "Concurrent generation should produce unique UUIDs")
    }

    func testConcurrentGenerationAtSameTimestamp() {
        // GIVEN a specific timestamp
        let timestamp: TimeInterval = 1609459200.0
        let expectation = XCTestExpectation(description: "Concurrent generation completes")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        var uuids: [UUID] = []
        let lock = NSLock()

        // WHEN generating UUIDs concurrently with same timestamp
        for _ in 0..<100 {
            group.enter()
            queue.async {
                let uuid = UUIDv7.generate(at: timestamp)
                lock.lock()
                uuids.append(uuid)
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all should be unique despite same timestamp
        let uniqueUUIDs = Set(uuids)
        XCTAssertEqual(uniqueUUIDs.count, 100,
                      "Random bits should ensure uniqueness even with same timestamp")
    }

    // MARK: - Timestamp Precision Tests

    func testMillisecondPrecisionIsPreserved() {
        // GIVEN timestamps with millisecond precision
        let baseTimestamp = 1609459200.0
        let timestamps = [
            baseTimestamp,
            baseTimestamp + 0.001,  // +1ms
            baseTimestamp + 0.010,  // +10ms
            baseTimestamp + 0.100,  // +100ms
            baseTimestamp + 1.000   // +1s
        ]

        for (index, timestamp) in timestamps.enumerated() {
            // WHEN generating and extracting
            let uuid = UUIDv7.generate(at: timestamp)
            let extracted = UUIDv7.extractTimestamp(from: uuid)

            // THEN precision should be within 1ms
            XCTAssertEqual(extracted, timestamp, accuracy: 0.001,
                          "Failed for timestamp \(index): \(timestamp)")
        }
    }

    func testSubMillisecondPrecisionIsLost() {
        // GIVEN timestamp with microsecond precision
        let timestamp = 1609459200.123456  // 6 decimal places

        // WHEN generating and extracting
        let uuid = UUIDv7.generate(at: timestamp)
        let extracted = UUIDv7.extractTimestamp(from: uuid)

        // THEN precision is limited to milliseconds (3 decimal places)
        // The difference should be less than 1ms but may not be exact
        XCTAssertEqual(extracted, timestamp, accuracy: 0.001,
                      "Precision should be limited to milliseconds")
    }

    // MARK: - Edge Cases

    func testGenerateWithNegativeTimestamp() {
        // GIVEN negative timestamp (before Unix epoch)
        let timestamp: TimeInterval = -1000.0

        // WHEN generating UUID
        // Note: UUIDv7 spec doesn't define behavior for negative timestamps
        // This test documents current implementation behavior
        let uuid = UUIDv7.generate(at: timestamp)

        // THEN should not crash
        XCTAssertNotNil(uuid)
        // Extraction may not return meaningful value for negative timestamps
    }

    func testGenerateWithVeryLargeTimestamp() {
        // GIVEN very large timestamp (far future - year 10000)
        let timestamp: TimeInterval = 253402300800.0

        // WHEN generating UUID
        let uuid = UUIDv7.generate(at: timestamp)

        // THEN should handle large values
        // Note: 48-bit timestamp overflows around year 10889
        let extracted = UUIDv7.extractTimestamp(from: uuid)
        XCTAssertNotNil(uuid)
        XCTAssertGreaterThan(extracted, 0)
    }

    func testGenerateWithTimestampNearOverflow() {
        // GIVEN timestamp near 48-bit overflow
        // 48 bits of milliseconds = 2^48 ms = ~8925 years from epoch
        let maxSafeTimestamp: TimeInterval = (Double(1 << 48) - 1) / 1000.0

        // WHEN generating UUID
        let uuid = UUIDv7.generate(at: maxSafeTimestamp)

        // THEN should handle without overflow
        let extracted = UUIDv7.extractTimestamp(from: uuid)
        XCTAssertEqual(extracted, maxSafeTimestamp, accuracy: 1.0)
    }

    // MARK: - Performance Tests

    func testGenerationPerformance() {
        // Test that we can generate UUIDs quickly
        measure {
            for _ in 0..<1000 {
                _ = UUIDv7.generate()
            }
        }
    }

    func testExtractionPerformance() {
        // GIVEN pre-generated UUIDs
        var uuids: [UUID] = []
        for _ in 0..<1000 {
            uuids.append(UUIDv7.generate())
        }

        // THEN extraction should be fast
        measure {
            for uuid in uuids {
                _ = UUIDv7.extractTimestamp(from: uuid)
            }
        }
    }

    // MARK: - Integration with Note Model

    func testUUIDv7WorksAsNoteIdentifier() {
        // GIVEN a note with UUIDv7 identifier
        let noteId = UUIDv7.generate()
        let note = Note(
            id: noteId,
            created: Date(),
            device: "Test Device",
            location: nil,
            content: "Test content",
            title: "Test",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // WHEN using the note
        // THEN ID should work as expected
        XCTAssertEqual(note.id, noteId)
        XCTAssertTrue(note.id.uuidString.count > 0)
    }

    func testMultipleNotesHaveOrderedIDs() {
        // GIVEN multiple notes created in sequence
        var notes: [Note] = []
        for i in 0..<10 {
            Thread.sleep(forTimeInterval: 0.001) // Ensure different timestamps
            let note = Note(
                id: UUIDv7.generate(),
                created: Date(),
                device: "Test",
                location: nil,
                content: "Note \(i)",
                title: "Test \(i)",
                backlinks: [],
                unknownFrontmatterFields: [:]
            )
            notes.append(note)
        }

        // WHEN sorting by ID timestamp
        let sorted = notes.sorted {
            UUIDv7.extractTimestamp(from: $0.id) < UUIDv7.extractTimestamp(from: $1.id)
        }

        // THEN should be in creation order
        for i in 0..<notes.count {
            XCTAssertEqual(sorted[i].id, notes[i].id,
                          "Note \(i) should be in correct position")
        }
    }
}
