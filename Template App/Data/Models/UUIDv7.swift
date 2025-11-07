// ABOUTME: UUID version 7 implementation for timestamp-ordered identifiers
// ABOUTME: Generates sortable UUIDs based on current timestamp

import Foundation

/// UUID Version 7 generator following RFC draft
/// Provides timestamp-ordered UUIDs for better database performance and natural ordering
enum UUIDv7 {

    /// Generate a new UUID v7
    /// - Returns: A new UUID v7 with embedded timestamp
    static func generate() -> UUID {
        let timestamp = Date().timeIntervalSince1970
        return generate(at: timestamp)
    }

    /// Generate a UUID v7 at a specific timestamp
    /// - Parameter timestamp: The timestamp to embed in the UUID
    /// - Returns: A new UUID v7 with the specified timestamp
    static func generate(at timestamp: TimeInterval) -> UUID {
        // Convert timestamp to milliseconds
        let milliseconds = UInt64(timestamp * 1000)

        // UUID v7 format:
        // 48 bits: timestamp in milliseconds
        // 4 bits: version (7)
        // 12 bits: random
        // 2 bits: variant (10)
        // 62 bits: random

        var bytes = [UInt8](repeating: 0, count: 16)

        // First 48 bits: timestamp (6 bytes)
        bytes[0] = UInt8((milliseconds >> 40) & 0xFF)
        bytes[1] = UInt8((milliseconds >> 32) & 0xFF)
        bytes[2] = UInt8((milliseconds >> 24) & 0xFF)
        bytes[3] = UInt8((milliseconds >> 16) & 0xFF)
        bytes[4] = UInt8((milliseconds >> 8) & 0xFF)
        bytes[5] = UInt8(milliseconds & 0xFF)

        // Next 2 bytes: version + random
        let random12 = UInt16.random(in: 0..<0x1000)  // 12 bits of random
        bytes[6] = UInt8(0x70 | ((random12 >> 8) & 0x0F))  // Version 7 (0111) + 4 bits random
        bytes[7] = UInt8(random12 & 0xFF)  // 8 bits random

        // Next 2 bytes: variant + random
        let random14 = UInt16.random(in: 0..<0x4000)  // 14 bits of random
        bytes[8] = UInt8(0x80 | ((random14 >> 8) & 0x3F))  // Variant 10 + 6 bits random
        bytes[9] = UInt8(random14 & 0xFF)  // 8 bits random

        // Last 6 bytes: random
        for i in 10..<16 {
            bytes[i] = UInt8.random(in: 0...255)
        }

        // Create UUID from bytes
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// Extract timestamp from UUID v7
    /// - Parameter uuid: The UUID v7 to extract timestamp from
    /// - Returns: Timestamp as TimeInterval (seconds since epoch)
    static func extractTimestamp(from uuid: UUID) -> TimeInterval {
        let bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }

        // Extract first 48 bits (6 bytes) as milliseconds
        let milliseconds: UInt64 =
            (UInt64(bytes[0]) << 40) |
            (UInt64(bytes[1]) << 32) |
            (UInt64(bytes[2]) << 24) |
            (UInt64(bytes[3]) << 16) |
            (UInt64(bytes[4]) << 8) |
            UInt64(bytes[5])

        // Convert to seconds
        return TimeInterval(milliseconds) / 1000.0
    }
}
