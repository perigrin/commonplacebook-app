// ABOUTME: Core Note model for Zettelkasten system
// ABOUTME: Represents a single note with metadata, content, and backlinks

import Foundation

/// A note in the Zettelkasten system
struct Note: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    let created: Date
    let device: String
    let location: Location?
    var content: String
    var title: String
    var backlinks: Set<UUID>  // Set for O(1) add/remove/contains
    var unknownFrontmatterFields: [String: AnyCodable]  // Preserve unknown YAML fields with type information

    /// Check if note is valid
    var isValid: Bool {
        // Title and content must not be empty
        guard !title.isEmpty else { return false }
        guard !content.isEmpty else { return false }
        guard !device.isEmpty else { return false }

        // If location exists, it must be valid
        if let location = location {
            guard location.isValid else { return false }
        }

        return true
    }

    init(
        id: UUID,
        created: Date,
        device: String,
        location: Location?,
        content: String,
        title: String,
        backlinks: Set<UUID> = [],
        unknownFrontmatterFields: [String: AnyCodable] = [:]
    ) {
        self.id = id
        self.created = created
        self.device = device
        self.location = location
        self.content = content
        self.title = title
        self.backlinks = backlinks
        self.unknownFrontmatterFields = unknownFrontmatterFields
    }

    /// Add a backlink to this note
    /// - Parameter noteId: The ID of the note that links to this note
    mutating func addBacklink(_ noteId: UUID) {
        backlinks.insert(noteId)  // Set automatically handles duplicates, O(1)
    }

    /// Remove a backlink from this note
    /// - Parameter noteId: The ID of the note to remove
    mutating func removeBacklink(_ noteId: UUID) {
        backlinks.remove(noteId)  // O(1) removal with Set
    }

    /// Hash for Hashable conformance
    /// All fields used in equality comparison must be hashed to maintain Hashable contract
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(created)
        hasher.combine(device)
        hasher.combine(location)
        hasher.combine(content)
        hasher.combine(title)
        hasher.combine(backlinks)
        hasher.combine(unknownFrontmatterFields)
    }

    /// Equality for Equatable conformance
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.id == rhs.id &&
               lhs.created == rhs.created &&
               lhs.device == rhs.device &&
               lhs.location == rhs.location &&
               lhs.content == rhs.content &&
               lhs.title == rhs.title &&
               lhs.backlinks == rhs.backlinks &&
               lhs.unknownFrontmatterFields == rhs.unknownFrontmatterFields
    }
}
