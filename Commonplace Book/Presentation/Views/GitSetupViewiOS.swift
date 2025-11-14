// ABOUTME: iOS git setup wizard using Working Copy app
// ABOUTME: Guides user through Working Copy installation, repository configuration, and testing

import SwiftUI

#if os(iOS)
/// iOS git setup wizard view
struct GitSetupViewiOS: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ViewModel()

    enum SetupStep: Int, CaseIterable {
        case welcome
        case installWorkingCopy
        case configureRepository
        case cloneRepository
        case testConnection
        case complete

        var title: String {
            switch self {
            case .welcome:
                return "Welcome to Git Integration"
            case .installWorkingCopy:
                return "Install Working Copy"
            case .configureRepository:
                return "Configure Repository"
            case .cloneRepository:
                return "Clone Repository"
            case .testConnection:
                return "Test Connection"
            case .complete:
                return "Setup Complete"
            }
        }
    }

    var body: some View {
        NavigationStack {
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
            .navigationTitle(viewModel.currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.checkWorkingCopy()
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 4) {
            ForEach(SetupStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)

                if step != SetupStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < viewModel.currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var currentStepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            welcomeStep
        case .installWorkingCopy:
            installWorkingCopyStep
        case .configureRepository:
            configureRepositoryStep
        case .cloneRepository:
            cloneRepositoryStep
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

            Text("iOS git sync uses Working Copy app")
                .font(.headline)

            Text("Working Copy is a powerful git client for iOS that handles all git operations, SSH keys, and conflict resolution.")
                .foregroundColor(.secondary)
                .font(.callout)

            Divider()

            Text("This wizard will guide you through:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Installing Working Copy (if needed)")
                Text("2. Configuring your repository")
                Text("3. Cloning your repository")
                Text("4. Testing the connection")
            }
            .foregroundColor(.secondary)
            .padding(.leading)
        }
    }

    private var installWorkingCopyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Install Working Copy")
                .font(.title2)
                .fontWeight(.bold)

            if viewModel.isWorkingCopyInstalled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Working Copy is installed")
                        .fontWeight(.semibold)
                }

                Text("Working Copy is already installed on your device. You can proceed to configure your repository.")
                    .foregroundColor(.secondary)
                    .font(.callout)

                Button {
                    Task {
                        await viewModel.openWorkingCopy()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.forward.app")
                        Text("Open Working Copy")
                    }
                }
                .buttonStyle(.bordered)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Working Copy is not installed")
                        .fontWeight(.semibold)
                }

                Text("Working Copy is required for git synchronization on iOS. It's a powerful git client that handles SSH keys, repositories, and conflict resolution.")
                    .foregroundColor(.secondary)
                    .font(.callout)

                Text("Working Copy Pro is required for push operations. The free version allows cloning and viewing repositories.")
                    .foregroundColor(.orange)
                    .font(.caption)

                Button {
                    viewModel.openAppStore()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.app")
                        Text("Get Working Copy from App Store")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Divider()

                Text("After installing Working Copy, return here and tap 'Check Again'.")
                    .font(.callout)
                    .foregroundColor(.secondary)

                Button {
                    Task {
                        await viewModel.checkWorkingCopy()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Check Again")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var configureRepositoryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configure Repository")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your git repository details. This repository will be used to sync your notes.")
                .foregroundColor(.secondary)
                .font(.callout)

            VStack(alignment: .leading, spacing: 12) {
                Text("Repository URL")
                    .font(.headline)

                TextField("git@github.com:username/notes.git", text: $viewModel.repositoryURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.repositoryURL) { _, _ in
                        viewModel.extractRepositoryName()
                    }

                Text("SSH or HTTPS URL to your git repository")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Repository Name")
                    .font(.headline)

                TextField("my-notes", text: $viewModel.repositoryName)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                Text("Short name for this repository (used by Working Copy)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !viewModel.isValidRepositoryURL {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("Please enter a valid repository URL")
                        .font(.callout)
                }
                .foregroundColor(.orange)
            }
        }
    }

    private var cloneRepositoryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clone Repository")
                .font(.title2)
                .fontWeight(.bold)

            Text("Now we'll open Working Copy to clone your repository.")
                .foregroundColor(.secondary)
                .font(.callout)

            VStack(alignment: .leading, spacing: 8) {
                Text("Repository: \(viewModel.repositoryName)")
                    .font(.headline)
                Text("URL: \(viewModel.repositoryURL)")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            Divider()

            Text("Steps:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Tap 'Clone in Working Copy' below")
                Text("2. Working Copy will open")
                Text("3. Follow prompts to clone the repository")
                Text("4. Return to this app when done")
            }
            .foregroundColor(.secondary)
            .padding(.leading)

            Button {
                Task {
                    await viewModel.cloneInWorkingCopy()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.doc")
                    Text("Clone in Working Copy")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isCloning)

            if viewModel.isCloning {
                HStack {
                    ProgressView()
                    Text("Opening Working Copy...")
                }
                .foregroundColor(.secondary)
            }
        }
    }

    private var testConnectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test Connection")
                .font(.title2)
                .fontWeight(.bold)

            Text("Let's verify that everything is set up correctly.")
                .foregroundColor(.secondary)
                .font(.callout)

            Button {
                Task {
                    await viewModel.testConnection()
                }
            } label: {
                HStack {
                    if viewModel.isTesting {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.shield")
                    }
                    Text(viewModel.isTesting ? "Testing..." : "Test Connection")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isTesting)

            if viewModel.testPassed {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connection successful!")
                        .fontWeight(.semibold)
                }

                Text("Your git integration is working correctly. Notes will be automatically synced via Working Copy.")
                    .foregroundColor(.secondary)
                    .font(.callout)
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

            Text("Git synchronization is now enabled")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Label("Auto-commit enabled", systemImage: "checkmark.circle")
                Label("Background push enabled", systemImage: "checkmark.circle")
                Label("Periodic pull enabled", systemImage: "checkmark.circle")
            }
            .foregroundColor(.secondary)

            Divider()

            Text("Your notes will be automatically synchronized via Working Copy. You can manage git settings in the app's Settings.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if viewModel.currentStep.rawValue > 0 {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if viewModel.currentStep == .complete {
                Button("Done") {
                    viewModel.finishSetup()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Next") {
                    viewModel.nextStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceed(from: viewModel.currentStep))
            }
        }
        .padding()
    }

    // MARK: - View Model

    @MainActor
    class ViewModel: ObservableObject {
        @Published var currentStep: SetupStep = .welcome
        @Published var repositoryURL: String = ""
        @Published var repositoryName: String = ""
        @Published var isWorkingCopyInstalled: Bool = false
        @Published var isCloning: Bool = false
        @Published var isTesting: Bool = false
        @Published var testPassed: Bool = false
        @Published var errorMessage: String?

        private let workingCopyService = WorkingCopyService()
        private let appStoreURL = "https://apps.apple.com/app/working-copy-git-client/id896694807"

        var isValidRepositoryURL: Bool {
            guard !repositoryURL.isEmpty else { return false }

            // Check for common git URL patterns
            return repositoryURL.contains("github.com") ||
                   repositoryURL.contains("gitlab.com") ||
                   repositoryURL.contains("bitbucket.org") ||
                   repositoryURL.hasPrefix("git@") ||
                   repositoryURL.hasPrefix("https://") ||
                   repositoryURL.hasPrefix("ssh://")
        }

        func canProceed(from step: SetupStep) -> Bool {
            switch step {
            case .welcome:
                return true
            case .installWorkingCopy:
                return isWorkingCopyInstalled
            case .configureRepository:
                return isValidRepositoryURL && !repositoryName.isEmpty
            case .cloneRepository:
                return true
            case .testConnection:
                return testPassed
            case .complete:
                return true
            }
        }

        func nextStep() {
            guard let currentIndex = SetupStep.allCases.firstIndex(of: currentStep),
                  currentIndex < SetupStep.allCases.count - 1 else {
                return
            }

            currentStep = SetupStep.allCases[currentIndex + 1]
        }

        func previousStep() {
            guard let currentIndex = SetupStep.allCases.firstIndex(of: currentStep),
                  currentIndex > 0 else {
                return
            }

            currentStep = SetupStep.allCases[currentIndex - 1]
        }

        func checkWorkingCopy() async {
            isWorkingCopyInstalled = await workingCopyService.isWorkingCopyInstalled()
        }

        func openWorkingCopy() async {
            do {
                try await workingCopyService.openRepository(repository: repositoryName.isEmpty ? "default" : repositoryName)
            } catch {
                errorMessage = "Failed to open Working Copy: \(error.localizedDescription)"
            }
        }

        func openAppStore() {
            if let url = URL(string: appStoreURL) {
                UIApplication.shared.open(url)
            }
        }

        func extractRepositoryName() {
            // Extract repository name from URL
            // Examples:
            // git@github.com:user/repo.git -> repo
            // https://github.com/user/repo.git -> repo

            var name = repositoryURL
                .replacingOccurrences(of: ".git", with: "")
                .components(separatedBy: "/")
                .last ?? ""

            // If still contains @, split by :
            if name.contains("@") {
                name = name.components(separatedBy: ":").last?.components(separatedBy: "/").last ?? ""
            }

            if !name.isEmpty && name != repositoryName {
                repositoryName = name
            }
        }

        func cloneInWorkingCopy() async {
            isCloning = true
            defer { isCloning = false }

            do {
                try await workingCopyService.clone(url: repositoryURL, to: repositoryName)
            } catch {
                errorMessage = "Failed to clone repository: \(error.localizedDescription)"
            }
        }

        func testConnection() async {
            isTesting = true
            defer { isTesting = false }

            do {
                // Try to get status from Working Copy
                _ = try await workingCopyService.status(repository: repositoryName)
                testPassed = true
            } catch {
                errorMessage = "Connection test failed: \(error.localizedDescription)"
                testPassed = false
            }
        }

        func finishSetup() {
            // Save configuration to UserDefaults or app state
            UserDefaults.standard.set(repositoryName, forKey: "GitRepositoryName")
            UserDefaults.standard.set(repositoryURL, forKey: "GitRepositoryURL")
            UserDefaults.standard.set(true, forKey: "GitSyncEnabled")
        }
    }
}
#endif
