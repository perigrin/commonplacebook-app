// ABOUTME: Full capture interface with microphone button, waveform, and transcription
// ABOUTME: Handles speech-to-text recording with visual feedback and note creation

import SwiftUI

/// Capture mode: speech or manual text
enum CaptureMode: String, CaseIterable {
    case speech = "Speech"
    case text = "Text"
}

struct CaptureView: View {
    @StateObject private var viewModel: CaptureViewModel
    @State private var showingPermissionAlert = false
    @State private var isProcessingTap = false
    @State private var captureMode: CaptureMode = .speech
    @State private var manualTitle: String = ""
    @State private var manualContent: String = ""

    private let manualNoteCreator: ManualNoteCreator

    init(viewModel: CaptureViewModel, manualNoteCreator: ManualNoteCreator) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.manualNoteCreator = manualNoteCreator
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mode toggle
                Picker("Capture Mode", selection: $captureMode) {
                    ForEach(CaptureMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .accessibilityIdentifier("modeToggle")

                // Content based on mode
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    if captureMode == .speech {
                        speechCaptureView
                    } else {
                        textCaptureView
                    }
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings", action: openSettings)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Speech recognition permission is required to capture notes. Please enable it in Settings.")
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { _ in viewModel.error = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An unknown error occurred")
            }
        }
        .accessibilityIdentifier("Capture")
    }

    // MARK: - Speech Capture View

    private var speechCaptureView: some View {
        VStack(spacing: 40) {
            Spacer()

            // Waveform visualization (shown during recording)
            if viewModel.isRecording {
                WaveformView(
                    isRecording: Binding(
                        get: { viewModel.isRecording },
                        set: { _ in }
                    ),
                    audioLevel: Binding(
                        get: { viewModel.audioLevel },
                        set: { _ in }
                    ),
                    waveformColor: .blue
                )
                .frame(height: 80)
                .accessibilityIdentifier("waveformView")
                .transition(.opacity.combined(with: .scale))
            }

            // Microphone button
            microphoneButton

            // Transcription preview (shown after stopping)
            if !viewModel.isRecording && !viewModel.transcription.isEmpty {
                transcriptionSection
            }

            // Action buttons (shown when transcription exists)
            if !viewModel.isRecording && !viewModel.transcription.isEmpty {
                speechActionButtons
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Text Capture View

    private var textCaptureView: some View {
        VStack(spacing: 20) {
            // Title field (optional)
            TextField("Title (optional)", text: $manualTitle)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("titleField")

            // Content editor
            ZStack(alignment: .topLeading) {
                if manualContent.isEmpty {
                    Text("Enter your note here...")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $manualContent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .accessibilityIdentifier("contentEditor")
            }

            // Action buttons
            textActionButtons
        }
        .padding()
    }

    // MARK: - Microphone Button

    private var microphoneButton: some View {
        Button(action: handleMicrophoneTap) {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.blue)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel(viewModel.isRecording ? "Stop Recording" : "Start Recording")
        .accessibilityIdentifier("microphoneButton")
        .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isRecording)
    }

    // MARK: - Transcription Section

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcription")
                .font(.headline)
                .foregroundColor(.secondary)

            ScrollView {
                Text(viewModel.transcription)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
            .frame(maxHeight: 200)
            .accessibilityIdentifier("transcriptionText")
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.3), value: viewModel.transcription)
    }

    // MARK: - Action Buttons

    private var speechActionButtons: some View {
        HStack(spacing: 20) {
            // Cancel button
            Button(action: handleCancel) {
                HStack {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }
            .accessibilityIdentifier("cancelButton")

            // Save button
            Button(action: handleSave) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Save")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .accessibilityIdentifier("saveButton")
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.3), value: viewModel.transcription)
    }

    private var textActionButtons: some View {
        HStack(spacing: 20) {
            // Cancel button
            Button(action: handleTextCancel) {
                HStack {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }
            .accessibilityIdentifier("cancelButton")

            // Save button
            Button(action: handleTextSave) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Save")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(manualContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(manualContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("saveButton")
        }
    }

    // MARK: - Actions

    @MainActor
    private func handleMicrophoneTap() {
        guard !isProcessingTap else { return }
        isProcessingTap = true

        if viewModel.isRecording {
            // Stop recording
            Task {
                let note = await viewModel.stopRecording()
                isProcessingTap = false

                if note == nil && !viewModel.transcription.isEmpty {
                    // Show feedback that transcription was empty
                    viewModel.error = CaptureViewModelError.emptyTranscription
                }
            }
        } else {
            // Start recording
            Task {
                await viewModel.startRecording()
                isProcessingTap = false

                // Check if permission was denied
                if let error = viewModel.error as? CaptureViewModelError,
                   case .permissionDenied = error {
                    showingPermissionAlert = true
                }
            }
        }
    }

    @MainActor
    private func handleSave() {
        Task {
            if let note = await viewModel.saveNote() {
                // Note saved successfully
                // Could show confirmation or haptic feedback
                #if DEBUG
                print("Note saved: \(note.id)")
                #endif
            }
        }
    }

    @MainActor
    private func handleCancel() {
        viewModel.cancelRecording()
    }

    @MainActor
    private func handleTextSave() {
        Task {
            do {
                let note = try await manualNoteCreator.createNote(
                    title: manualTitle.isEmpty ? nil : manualTitle,
                    content: manualContent
                )

                // Clear fields on success
                manualTitle = ""
                manualContent = ""

                #if DEBUG
                print("Manual note saved: \(note.id)")
                #endif
            } catch {
                viewModel.error = error
            }
        }
    }

    @MainActor
    private func handleTextCancel() {
        // Clear fields
        manualTitle = ""
        manualContent = ""
    }

    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Preview

#Preview("Initial State") {
    let repository = InMemoryNoteRepository()
    let metadataCollector = MetadataCollector()

    return CaptureView(
        viewModel: CaptureViewModel(
            speechService: SpeechRecognitionService(),
            audioMonitor: AudioLevelMonitor(),
            metadataCollector: metadataCollector,
            repository: repository
        ),
        manualNoteCreator: ManualNoteCreator(
            repository: repository,
            metadataCollector: metadataCollector
        )
    )
}
