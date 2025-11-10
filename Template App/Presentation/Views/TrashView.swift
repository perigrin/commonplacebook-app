// ABOUTME: View displaying soft-deleted notes with restore and permanent delete options
// ABOUTME: Shows auto-purge settings and trash management UI

import SwiftUI

/// View for managing trashed notes
struct TrashView: View {
    @ObservedObject var trashService: TrashService
    @State private var trashedNotes: [Note] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingPurgeConfirmation = false
    @State private var noteToPermDelete: Note?

    var body: some View {
        List {
            // Auto-purge info section
            Section {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.secondary)

                    Text("Auto-purge after \(autoPurgeDurationText)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Trashed notes
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if trashedNotes.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "trash.slash")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No items in trash")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        Spacer()
                    }
                } else {
                    ForEach(trashedNotes) { note in
                        TrashNoteRow(
                            note: note,
                            onRestore: { restoreNote(note) },
                            onPermanentDelete: {
                                noteToPermDelete = note
                                showingPurgeConfirmation = true
                            }
                        )
                    }
                }
            } header: {
                if !trashedNotes.isEmpty {
                    Text("\(trashedNotes.count) \(trashedNotes.count == 1 ? "item" : "items")")
                }
            }
        }
        .navigationTitle("Trash")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTrashedNotes()
        }
        .refreshable {
            await loadTrashedNotes()
        }
        .alert("Permanently Delete?", isPresented: $showingPurgeConfirmation, presenting: noteToPermDelete) { note in
            Button("Cancel", role: .cancel) {
                noteToPermDelete = nil
            }
            Button("Delete Permanently", role: .destructive) {
                Task {
                    await permanentlyDelete(note)
                }
            }
        } message: { note in
            Text("This note will be permanently deleted and cannot be recovered.\n\n\"\(note.title)\"")
        }
    }

    // MARK: - Computed Properties

    private var autoPurgeDurationText: String {
        if let duration = trashService.currentPurgeDuration {
            return duration.displayName
        }

        let days = Int(trashService.autoPurgeAfter / (24 * 60 * 60))
        return "\(days) days"
    }

    // MARK: - Actions

    private func loadTrashedNotes() async {
        isLoading = true
        defer { isLoading = false }

        do {
            trashedNotes = try await trashService.listTrashed()
                .sorted { ($0.deletedAt ?? Date.distantPast) > ($1.deletedAt ?? Date.distantPast) }
        } catch {
            self.error = error
            Logger.error("Failed to load trashed notes: \(error)", category: .general)
        }
    }

    private func restoreNote(_ note: Note) {
        Task {
            do {
                try await trashService.restore(id: note.id)
                await loadTrashedNotes()
            } catch {
                self.error = error
                Logger.error("Failed to restore note: \(error)", category: .general)
            }
        }
    }

    private func permanentlyDelete(_ note: Note) async {
        do {
            try await trashService.purge(id: note.id)
            noteToPermDelete = nil
            await loadTrashedNotes()
        } catch {
            self.error = error
            Logger.error("Failed to purge note: \(error)", category: .general)
        }
    }
}

// MARK: - Trash Note Row

struct TrashNoteRow: View {
    let note: Note
    let onRestore: () -> Void
    let onPermanentDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(note.title)
                .font(.headline)
                .foregroundColor(.primary)

            // Deletion info
            if let deletedAt = note.deletedAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Deleted \(deletedAt, style: .relative) ago")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onRestore()
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    onPermanentDelete()
                } label: {
                    Label("Delete Forever", systemImage: "trash.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Previews

struct TrashView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TrashView(trashService: mockTrashService())
        }
    }

    static func mockTrashService() -> TrashService {
        let mockRepo = MockNoteRepositoryForPreview()
        return TrashService(repository: mockRepo)
    }
}

// MARK: - Preview Mock

private class MockNoteRepositoryForPreview: NoteRepository {
    func create(note: Note) async throws -> Note { note }
    func read(id: UUID) async throws -> Note? { nil }
    func update(note: Note) async throws -> Note { note }
    func delete(id: UUID) async throws { }
    func list() async throws -> [Note] { [] }
    func search(query: String) async throws -> [Note] { [] }

    func listTrashed() async throws -> [Note] {
        [
            Note(
                id: UUID(),
                created: Date().addingTimeInterval(-10 * 24 * 60 * 60),
                device: "iPhone",
                location: nil,
                content: "This is a deleted note",
                title: "Deleted Note 1",
                deletedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60)
            ),
            Note(
                id: UUID(),
                created: Date().addingTimeInterval(-20 * 24 * 60 * 60),
                device: "iPad",
                location: nil,
                content: "Another deleted note",
                title: "Deleted Note 2",
                deletedAt: Date().addingTimeInterval(-5 * 24 * 60 * 60)
            )
        ]
    }

    func restore(id: UUID) async throws { }
    func purge(id: UUID) async throws { }
}
