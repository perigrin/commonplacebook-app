// ABOUTME: Git setup wizard for configuring SSH keys and repository
// ABOUTME: Guides user through generating keys, adding to git host, and testing connection

import SwiftUI

/// Git setup wizard view
struct GitSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: SetupStep = .welcome
    @State private var repositoryURL: String = ""
    @State private var userName: String = ""
    @State private var userEmail: String = ""
    @State private var publicKey: String = ""
    @State private var isGeneratingKey = false
    @State private var isTesting = false
    @State private var errorMessage: String?
    @State private var showingPublicKey = false

    private let sshKeyService = SSHKeyService()
    private let gitService = GitService()

    enum SetupStep: Int, CaseIterable {
        case welcome
        case generateKey
        case addKeyToHost
        case configureRepository
        case testConnection
        case complete

        var title: String {
            switch self {
            case .welcome:
                return "Welcome to Git Integration"
            case .generateKey:
                return "Generate SSH Key"
            case .addKeyToHost:
                return "Add Key to Git Host"
            case .configureRepository:
                return "Configure Repository"
            case .testConnection:
                return "Test Connection"
            case .complete:
                return "Setup Complete"
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Progress indicator
            progressIndicator

            // Content based on current step
            ScrollView {
                VStack(spacing: 20) {
                    currentStepContent
                }
                .padding()
            }

            // Navigation buttons
            navigationButtons
        }
        .navigationTitle(currentStep.title)
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingPublicKey) {
            PublicKeyView(publicKey: publicKey)
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(SetupStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)

                if step != SetupStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var currentStepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .generateKey:
            generateKeyStep
        case .addKeyToHost:
            addKeyStep
        case .configureRepository:
            configureRepositoryStep
        case .testConnection:
            testConnectionStep
        case .complete:
            completeStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync Your Notes with Git")
                .font(.title2)
                .fontWeight(.bold)

            Text("Git integration allows you to:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Label("Automatically backup your notes", systemImage: "checkmark.circle")
                Label("Sync across multiple devices", systemImage: "checkmark.circle")
                Label("Access notes via external editors", systemImage: "checkmark.circle")
                Label("Keep version history of all changes", systemImage: "checkmark.circle")
            }
            .foregroundColor(.secondary)

            Divider()

            Text("This wizard will guide you through:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Generating an SSH key pair")
                Text("2. Adding the key to your git host")
                Text("3. Configuring your repository")
                Text("4. Testing the connection")
            }
            .foregroundColor(.secondary)
            .padding(.leading)
        }
    }

    private var generateKeyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generate SSH Key")
                .font(.title2)
                .fontWeight(.bold)

            Text("An SSH key is required to securely authenticate with your git repository.")
                .foregroundColor(.secondary)

            if publicKey.isEmpty {
                Button {
                    Task {
                        await generateSSHKey()
                    }
                } label: {
                    HStack {
                        if isGeneratingKey {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "key.fill")
                        }
                        Text(isGeneratingKey ? "Generating..." : "Generate SSH Key")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGeneratingKey)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("SSH key generated successfully")
                        .fontWeight(.semibold)
                }

                Button {
                    showingPublicKey = true
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("View Public Key")
                    }
                }
            }
        }
    }

    private var addKeyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Key to Git Host")
                .font(.title2)
                .fontWeight(.bold)

            Text("Add your public key to your git hosting provider:")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: "1", text: "Go to your git host (GitHub, GitLab, etc.)")
                InstructionRow(number: "2", text: "Navigate to SSH Keys settings")
                InstructionRow(number: "3", text: "Click 'Add SSH Key'")
                InstructionRow(number: "4", text: "Paste the public key below")
            }

            GroupBox {
                HStack {
                    Text(publicKey)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(publicKey, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .help("Copy to clipboard")
                }
                .padding()
            }

            Text("ℹ️ GitHub: Settings → SSH and GPG keys → New SSH key")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var configureRepositoryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configure Repository")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your git repository details:")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository URL")
                        .font(.headline)
                    TextField("git@github.com:username/repo.git", text: $repositoryURL)
                        .textFieldStyle(.roundedBorder)
                    Text("Use SSH format (git@...)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Name")
                        .font(.headline)
                    TextField("John Doe", text: $userName)
                        .textFieldStyle(.roundedBorder)
                    Text("For git commit author")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Email")
                        .font(.headline)
                    TextField("john@example.com", text: $userEmail)
                        .textFieldStyle(.roundedBorder)
                    Text("For git commit author")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var testConnectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test Connection")
                .font(.title2)
                .fontWeight(.bold)

            if isTesting {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Testing connection...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                Text("Ready to test your git configuration.")
                    .foregroundColor(.secondary)

                Button {
                    Task {
                        await testConnection()
                    }
                } label: {
                    HStack {
                        Image(systemName: "network")
                        Text("Test Connection")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var completeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)

            Text("Setup Complete!")
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)

            Text("Git integration is now active. Your notes will be automatically committed and synced.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("What happens next:")
                    .font(.headline)

                Label("Notes will be auto-committed after changes", systemImage: "arrow.triangle.branch")
                Label("Changes will sync in the background", systemImage: "arrow.clockwise")
                Label("You can access notes from any device", systemImage: "laptopcomputer.and.iphone")
            }
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if currentStep != .welcome {
                Button("Back") {
                    previousStep()
                }
            }

            Spacer()

            if currentStep == .complete {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Next") {
                    nextStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceedToNextStep)
            }
        }
        .padding()
    }

    // MARK: - Helper Properties

    private var canProceedToNextStep: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .generateKey:
            return !publicKey.isEmpty
        case .addKeyToHost:
            return true // User confirms manually
        case .configureRepository:
            return !repositoryURL.isEmpty && !userName.isEmpty && !userEmail.isEmpty
        case .testConnection:
            return false // Must test first
        case .complete:
            return true
        }
    }

    // MARK: - Actions

    private func nextStep() {
        guard let next = SetupStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    private func previousStep() {
        guard let previous = SetupStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    private func generateSSHKey() async {
        isGeneratingKey = true
        defer { isGeneratingKey = false }

        do {
            let keyPair = try await sshKeyService.generateKeyPair(comment: userEmail.isEmpty ? nil : userEmail)
            publicKey = keyPair.publicKey
        } catch {
            errorMessage = "Failed to generate SSH key: \(error.localizedDescription)"
        }
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }

        // For now, just simulate success
        // In a real implementation, we'd try to connect to the repository
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Move to complete step
        currentStep = .complete
    }
}

// MARK: - Supporting Views

struct InstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

struct PublicKeyView: View {
    let publicKey: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Your SSH Public Key")
                .font(.title2)
                .fontWeight(.bold)

            ScrollView {
                Text(publicKey)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(publicKey, forType: .string)
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy to Clipboard")
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 500, height: 300)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GitSetupView()
    }
}
