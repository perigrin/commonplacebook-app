// ABOUTME: Row view component for displaying note in list
// ABOUTME: Shows title, preview (100 chars), and relative date with proper styling

import SwiftUI

struct NoteRowView: View {
    private enum Constants {
        static let previewCharacterLimit = 100
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title (bold)
            Text(note.title)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)

            // Preview text (gray, smaller, truncated to 100 chars)
            if !note.content.isEmpty {
                Text(previewText)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            // Relative date
            Text(relativeDate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var previewText: String {
        let cleaned = note.content
            .replacingOccurrences(of: "# \(note.title)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count <= Constants.previewCharacterLimit {
            return cleaned
        }

        let truncated = String(cleaned.prefix(Constants.previewCharacterLimit))
        return truncated + "..."
    }

    private var relativeDate: String {
        return Self.relativeDateFormatter.localizedString(for: note.created, relativeTo: Date())
    }
}

// MARK: - Previews

struct NoteRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            // Short content
            NoteRowView(note: Note(
                id: UUID(),
                created: Date().addingTimeInterval(-3600), // 1 hour ago
                device: "iPhone 15",
                location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0),
                content: "A short note about something interesting.",
                title: "Short Note",
                backlinks: [],
                unknownFrontmatterFields: [:]
            ))

            // Long content
            NoteRowView(note: Note(
                id: UUID(),
                created: Date().addingTimeInterval(-86400), // 1 day ago
                device: "iPhone 15",
                location: nil,
                content: "This is a very long note that contains more than one hundred characters and should be truncated to show only the preview with ellipsis at the end to indicate there is more content available.",
                title: "Long Note with Extended Content",
                backlinks: [],
                unknownFrontmatterFields: [:]
            ))

            // Empty content
            NoteRowView(note: Note(
                id: UUID(),
                created: Date().addingTimeInterval(-604800), // 1 week ago
                device: "iPhone 15",
                location: nil,
                content: "",
                title: "Empty Note",
                backlinks: [],
                unknownFrontmatterFields: [:]
            ))

            // Very old note
            NoteRowView(note: Note(
                id: UUID(),
                created: Date().addingTimeInterval(-365 * 24 * 3600), // 1 year ago
                device: "iPhone 15",
                location: nil,
                content: "An old note from last year.",
                title: "Old Note",
                backlinks: [],
                unknownFrontmatterFields: [:]
            ))
        }
        .listStyle(.plain)
    }
}
