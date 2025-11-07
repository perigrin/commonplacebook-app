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
    var backlinks: [UUID]

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
        backlinks: [UUID]
    ) {
        self.id = id
        self.created = created
        self.device = device
        self.location = location
        self.content = content
        self.title = title
        self.backlinks = backlinks
    }

    /// Add a backlink to this note
    /// - Parameter noteId: The ID of the note that links to this note
    mutating func addBacklink(_ noteId: UUID) {
        if !backlinks.contains(noteId) {
            backlinks.append(noteId)
        }
    }

    /// Remove a backlink from this note
    /// - Parameter noteId: The ID of the note to remove
    mutating func removeBacklink(_ noteId: UUID) {
        backlinks.removeAll { $0 == noteId }
    }

    /// Hash for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Equality for Equatable conformance
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.id == rhs.id &&
               lhs.created == rhs.created &&
               lhs.device == rhs.device &&
               lhs.location == rhs.location &&
               lhs.content == rhs.content &&
               lhs.title == rhs.title &&
               lhs.backlinks == rhs.backlinks
    }
}
