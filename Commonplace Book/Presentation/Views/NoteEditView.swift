// ABOUTME: Editable view for creating and modifying notes with markdown content
// ABOUTME: Raw markdown editor with title field, validation, and save/cancel actions

import SwiftUI

struct NoteEditView: View {
    @ObservedObject var viewModel: NoteViewModel
    @Environment(\.dismiss) private var dismiss

    let onSave: (() -> Void)?

    init(viewModel: NoteViewModel, onSave: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if let error = viewModel.error {
                    errorBanner(error: error)
                }

                editorContent
            }

            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .navigationTitle(viewModel.title.isEmpty ? "New Note" : "Edit Note")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await viewModel.save()
                        if viewModel.error == nil {
                            onSave?()
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    TextField("Note title", text: Binding(
                        get: { viewModel.title },
                        set: { viewModel.updateTitle($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                }

                Divider()

                // Content field (raw markdown)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Content")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Raw markdown editor")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: Binding(
                        get: { viewModel.content },
                        set: { viewModel.updateContent($0) }
                    ))
                    .font(.body)
                    .frame(minHeight: 300)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }

                // Metadata section (read-only)
                if !viewModel.device.isEmpty {
                    Divider()

                    metadataSection
                }

                Spacer()
            }
            .padding()
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metadata")
                .font(.headline)
                .foregroundColor(.secondary)

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
                Text(viewModel.device)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Location (if available)
            if let location = viewModel.location {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(formattedLocation(location))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func errorBanner(error: Error) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
        .background(Color.red)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                Text("Saving...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.secondary)
            .cornerRadius(12)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: viewModel.created)
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

struct NoteEditView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            // Editing existing note
            NoteEditView(
                viewModel: makeExistingNoteViewModel()
            )
            .previewDisplayName("Edit Existing Note")

            // Creating new note
            NoteEditView(
                viewModel: makeNewNoteViewModel()
            )
            .previewDisplayName("Create New Note")

            // With error
            NoteEditView(
                viewModel: makeViewModelWithError()
            )
            .previewDisplayName("With Error")
        }
    }

    @MainActor
    static func makeExistingNoteViewModel() -> NoteViewModel {
        let repository = InMemoryNoteRepository()
        let note = Note(
            id: UUID(),
            created: Date().addingTimeInterval(-3600),
            device: "iPhone 15 Pro",
            location: Location(latitude: 37.7749, longitude: -122.4194, accuracy: 10.0),
            content: """
            # Existing Note

            This is an existing note with some content.

            ## Features
            - Markdown support
            - Extended syntax
            - Footnotes[^1]

            [^1]: Footnote example
            """,
            title: "Existing Note",
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        Task {
            _ = try? await repository.create(note: note)
        }

        let viewModel = NoteViewModel(repository: repository, noteId: note.id)
        Task {
            await viewModel.load()
        }

        return viewModel
    }

    @MainActor
    static func makeNewNoteViewModel() -> NoteViewModel {
        let repository = InMemoryNoteRepository()
        let noteId = UUID()
        let viewModel = NoteViewModel(repository: repository, noteId: noteId)

        // Set initial values for new note
        viewModel.updateTitle("")
        viewModel.updateContent("")

        return viewModel
    }

    @MainActor
    static func makeViewModelWithError() -> NoteViewModel {
        let repository = InMemoryNoteRepository()
        let noteId = UUID()
        let viewModel = NoteViewModel(repository: repository, noteId: noteId)

        viewModel.updateTitle("")
        viewModel.updateContent("Some content")

        Task {
            await viewModel.save()
        }

        return viewModel
    }
}
