// ABOUTME: Main list view for displaying all notes with navigation
// ABOUTME: Handles loading states, errors, pull-to-refresh, and navigation to detail view

import SwiftUI

struct NoteListView: View {
    @ObservedObject var viewModel: NoteListViewModel
    @State private var selectedNote: Note?

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.notes.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    notesList
                }

                if viewModel.isLoading && viewModel.notes.isEmpty {
                    loadingView
                }
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note)
            }
            .task {
                await viewModel.loadNotes()
            }
        }
    }

    private var notesList: some View {
        List {
            ForEach(viewModel.notes) { note in
                NavigationLink(value: note) {
                    NoteRowView(note: note)
                }
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadNotes()
        }
        .overlay {
            if let error = viewModel.error {
                errorView(error: error)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Notes Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Pull down to refresh")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading notes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error.localizedDescription)
                    .font(.subheadline)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            Button("Dismiss") {
                viewModel.error = nil
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Previews

struct NoteListView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with notes
        Group {
            // With notes
            NoteListView(viewModel: makeViewModelWithNotes())
                .previewDisplayName("With Notes")

            // Empty state
            NoteListView(viewModel: makeEmptyViewModel())
                .previewDisplayName("Empty State")

            // Loading state
            NoteListView(viewModel: makeLoadingViewModel())
                .previewDisplayName("Loading")
        }
    }

    static func makeViewModelWithNotes() -> NoteListViewModel {
        let repository = InMemoryNoteRepository()
        let viewModel = NoteListViewModel(repository: repository, metadataCollector: nil)

        // Add test notes synchronously for preview
        Task { @MainActor in
            let note1 = Note(
                id: UUID(),
                created: Date().addingTimeInterval(-3600),
                device: "iPhone 15",
                location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0),
                content: "This is a sample note with some content that demonstrates how the preview looks in the list view.",
                title: "Sample Note 1",
                backlinks: [],
                unknownFrontmatterFields: [:]
            )

            let note2 = Note(
                id: UUID(),
                created: Date().addingTimeInterval(-86400),
                device: "iPhone 15",
                location: nil,
                content: "Another note with different content to show variety in the list.",
                title: "Sample Note 2",
                backlinks: [],
                unknownFrontmatterFields: [:]
            )

            _ = try? await repository.create(note: note1)
            _ = try? await repository.create(note: note2)
            await viewModel.loadNotes()
        }

        return viewModel
    }

    static func makeEmptyViewModel() -> NoteListViewModel {
        let repository = InMemoryNoteRepository()
        return NoteListViewModel(repository: repository, metadataCollector: nil)
    }

    static func makeLoadingViewModel() -> NoteListViewModel {
        let repository = InMemoryNoteRepository()
        let viewModel = NoteListViewModel(repository: repository, metadataCollector: nil)

        Task { @MainActor in
            await viewModel.loadNotes()
        }

        return viewModel
    }
}

// MARK: - Preview Helpers

#if DEBUG
/// Mock metadata collector for SwiftUI previews
actor MockMetadataCollector {
    private let deviceName: String
    private let location: Location?

    init(deviceName: String = "Preview Device", location: Location? = nil) {
        self.deviceName = deviceName
        self.location = location
    }

    func getCurrentDevice() -> String {
        return deviceName
    }

    func generateTimestamp() -> Date {
        return Date()
    }

    func getCurrentLocation() async -> Location? {
        return location
    }
}
#endif
