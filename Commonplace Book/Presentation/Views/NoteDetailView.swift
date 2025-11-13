// ABOUTME: Read-only detail view for displaying complete note information
// ABOUTME: Shows title, full content, and metadata (device, date, location) with formatting

import SwiftUI

struct NoteDetailView: View {
    let note: Note
    var repository: NoteRepository?
    @State private var showingEdit = false
    @State private var editViewModel: NoteViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(note.title)
                    .font(.title)
                    .fontWeight(.bold)

                // Metadata section
                metadataSection

                // Content
                Divider()

                Text(contentWithoutTitle)
                    .font(.body)
                    .textSelection(.enabled)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Note")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    openEditView()
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let viewModel = editViewModel {
                NavigationStack {
                    NoteEditView(viewModel: viewModel)
                }
            }
        }
    }

    private func openEditView() {
        // Use provided repository or fallback to in-memory for preview
        let repo = repository ?? InMemoryNoteRepository()

        Task {
            // If using fallback repository, load the note into it
            if repository == nil {
                _ = try? await repo.create(note: note)
            }

            // Create view model
            let viewModel = NoteViewModel(repository: repo, noteId: note.id)
            await viewModel.load()

            await MainActor.run {
                editViewModel = viewModel
                showingEdit = true
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Device
            HStack(spacing: 8) {
                Image(systemName: "iphone")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(note.device)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Location (if available)
            if let location = note.location {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(formattedLocation(location))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Backlinks (if any)
            if !note.backlinks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("\(note.backlinks.count) backlink\(note.backlinks.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var contentWithoutTitle: String {
        // Remove the title heading from content if it exists
        let titlePattern = "# \(note.title)"
        let cleaned = note.content
            .replacingOccurrences(of: titlePattern, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? note.content : cleaned
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: note.created)
    }

    private func formattedLocation(_ location: Location) -> String {
        let latDirection = location.latitude >= 0 ? "N" : "S"
        let lonDirection = location.longitude >= 0 ? "E" : "W"

        let lat = String(format: "%.4f°%@", abs(location.latitude), latDirection)
        let lon = String(format: "%.4f°%@", abs(location.longitude), lonDirection)

        return "\(lat), \(lon) (±\(Int(location.accuracy))m)"
    }
}

// MARK: - Previews

struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            // Note with all metadata
            NoteDetailView(note: Note(
                id: UUID(),
                created: Date().addingTimeInterval(-3600),
                device: "iPhone 15 Pro",
                location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0),
                content: """
                # Complete Note

                This is a note with all metadata including location.

                ## Features
                - Device info
                - Location data
                - Timestamp
                - Backlinks

                Multiple paragraphs of content to demonstrate scrolling behavior.
                """,
                title: "Complete Note",
                backlinks: [UUID(), UUID(), UUID()],
                unknownFrontmatterFields: [:]
            ))
            .previewDisplayName("With All Metadata")

            // Minimal note
            NoteDetailView(note: Note(
                id: UUID(),
                created: Date(),
                device: "iPhone 15",
                location: nil,
                content: "Simple note with minimal metadata.",
                title: "Minimal Note",
                backlinks: [],
                unknownFrontmatterFields: [:]
            ))
            .previewDisplayName("Minimal")

            // Long content note
            NoteDetailView(note: Note(
                id: UUID(),
                created: Date().addingTimeInterval(-86400),
                device: "iPhone 14",
                location: Location(latitude: 40.7128, longitude: -74.0060, accuracy: 50.0),
                content: String(repeating: "This is a long paragraph with substantial content. ", count: 50),
                title: "Long Content Note",
                backlinks: [UUID()],
                unknownFrontmatterFields: [:]
            ))
            .previewDisplayName("Long Content")
        }
    }
}
