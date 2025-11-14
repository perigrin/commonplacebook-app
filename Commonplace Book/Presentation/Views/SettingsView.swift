// ABOUTME: Comprehensive settings screen with all app configuration options
// ABOUTME: Manages privacy, security, search, trash, and app information settings

import SwiftUI
import CryptoKit

/// Main settings view for the application
struct SettingsView: View {
    @ObservedObject var biometricAuth: BiometricAuthService
    @ObservedObject var encryptionService: EncryptionService
    @ObservedObject var trashService: TrashService

    @State private var searchThreshold: Double = 0.7
    @State private var showingTrash = false
    @State private var showingAbout = false
    #if os(macOS)
    @State private var showingGitSetup = false
    #endif

    var body: some View {
        List {
            // Privacy & Security Section
            privacySecuritySection

            #if os(macOS)
            // Git Integration Section (macOS only)
            gitIntegrationSection
            #endif

            // Search Settings Section
            searchSettingsSection

            // Trash Settings Section
            trashSettingsSection

            // About Section
            aboutSection
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingTrash) {
            NavigationStack {
                TrashView(trashService: trashService)
            }
        }
        .sheet(isPresented: $showingAbout) {
            NavigationStack {
                AboutView()
            }
        }
        #if os(macOS)
        .sheet(isPresented: $showingGitSetup) {
            NavigationStack {
                GitSetupView()
            }
        }
        #endif
    }

    // MARK: - Sections

    // MARK: - Privacy & Security Section

    private var privacySecuritySection: some View {
        Section {
            // Biometric authentication toggle
            if biometricAuth.isBiometricAvailable() {
                Toggle(isOn: Binding(
                    get: { biometricAuth.isBiometricEnabled },
                    set: { biometricAuth.setBiometricEnabled($0) }
                )) {
                    HStack {
                        Image(systemName: biometricIconName)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text(biometricLockLabel)
                            Text("Lock app when in background")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Encryption status
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(encryptionService.isEncryptionEnabled ? .green : .secondary)

                VStack(alignment: .leading) {
                    Text("Database Encryption")
                    Text(encryptionService.isEncryptionEnabled ? "Enabled" : "Disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if encryptionService.isEncryptionEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        } header: {
            Text("Privacy & Security")
        } footer: {
            Text("Database encryption protects your notes at rest. Biometric lock adds an extra layer of security.")
        }
    }

    // MARK: - Git Integration Section

    #if os(macOS)
    private var gitIntegrationSection: some View {
        Section {
            // Setup/Configuration button
            Button {
                showingGitSetup = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.accentColor)
                    Text("Git Synchronization Setup")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)

        } header: {
            Text("Git Integration")
        } footer: {
            Text("Configure automatic git synchronization for your notes. Currently supported on macOS only.")
        }
    }
    #endif

    // MARK: - Search Settings Section

    private var searchSettingsSection: some View {
        Section {
            // Search threshold slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Search Relevance Threshold")
                    Spacer()
                    Text(String(format: "%.1f", searchThreshold))
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }

                Slider(value: $searchThreshold, in: 0.5...0.9, step: 0.05)
                    .tint(.accentColor)

                Text("Higher values show only more relevant results")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

        } header: {
            Text("Search Settings")
        } footer: {
            Text("Adjust how strict the semantic search is. Higher values (0.8-0.9) return fewer, more relevant results.")
        }
    }

    // MARK: - Trash Settings Section

    private var trashSettingsSection: some View {
        Section {
            // View trash
            Button {
                showingTrash = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.accentColor)
                    Text("View Trash")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)

            // Auto-purge duration picker
            Picker("Auto-Purge After", selection: Binding(
                get: { trashService.autoPurgeAfter },
                set: { trashService.setAutoPurgeAfter($0) }
            )) {
                ForEach(TrashService.PurgeDuration.allCases) { duration in
                    Text(duration.displayName).tag(duration.rawValue)
                }
            }

        } header: {
            Text("Trash")
        } footer: {
            Text("Deleted notes are automatically purged after the specified duration. You can restore notes before they're purged.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            // App version
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }

            // Build number
            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundColor(.secondary)
            }

            // About/Help
            Button {
                showingAbout = true
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.accentColor)
                    Text("About")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)

        } header: {
            Text("About")
        }
    }

    // MARK: - Computed Properties

    private var biometricIconName: String {
        switch biometricAuth.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock"
        }
    }

    private var biometricLockLabel: String {
        switch biometricAuth.biometricType {
        case .faceID:
            return "Face ID Lock"
        case .touchID:
            return "Touch ID Lock"
        case .none:
            return "Biometric Lock"
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Commonplace Book")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("A modern Zettelkasten app with speech capture, semantic search, and CRDT sync.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Features") {
                FeatureRow(icon: "mic.fill", title: "Speech Capture", description: "Record notes with your voice")
                FeatureRow(icon: "magnifyingglass", title: "Semantic Search", description: "Find notes by meaning, not just keywords")
                FeatureRow(icon: "icloud.fill", title: "iCloud Sync", description: "Seamless sync across devices")
                FeatureRow(icon: "lock.shield.fill", title: "Secure", description: "Biometric lock and encryption")
            }

            Section("Open Source") {
                Link(destination: URL(string: "https://github.com/perigrin/commonplacebook-app")!) {
                    HStack {
                        Image(systemName: "link")
                        Text("View on GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }
            }

            Section {
                Button("Done") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.accentColor)
            }
        }
        .navigationTitle("About")
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView(
                biometricAuth: mockBiometricAuth(),
                encryptionService: mockEncryptionService(),
                trashService: mockTrashService()
            )
        }
    }

    static func mockBiometricAuth() -> BiometricAuthService {
        let mock = MockSecurityManagerForPreview(biometricType: .faceID)
        return BiometricAuthService(securityManager: mock)
    }

    static func mockEncryptionService() -> EncryptionService {
        let mock = MockSecurityManagerForPreview(biometricType: .faceID)
        return EncryptionService(securityManager: mock)
    }

    static func mockTrashService() -> TrashService {
        TrashService(repository: MockNoteRepositoryForPreview())
    }
}

// MARK: - Preview Mocks

private class MockSecurityManagerForPreview: SecurityManaging {
    let biometricType: SecurityManager.BiometricType

    init(biometricType: SecurityManager.BiometricType) {
        self.biometricType = biometricType
    }

    func getBiometricType() -> SecurityManager.BiometricType { biometricType }
    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        completion(true, nil)
    }
    func authenticateWithDevicePasscode(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        completion(true, nil)
    }
    func storeInKeychain(_ data: Data, forKey key: String) -> Bool { true }
    func getFromKeychain(forKey key: String) -> Data? { nil }
    func deleteFromKeychain(forKey key: String) -> Bool { true }
    func encrypt(data: Data, with key: SymmetricKey) throws -> Data { data }
    func decrypt(data: Data, with key: SymmetricKey) throws -> Data { data }
}

private class MockNoteRepositoryForPreview: NoteRepository {
    func create(note: Note) async throws -> Note { note }
    func read(id: UUID) async throws -> Note? { nil }
    func update(note: Note) async throws -> Note { note }
    func delete(id: UUID) async throws { }
    func list() async throws -> [Note] { [] }
    func search(query: String) async throws -> [Note] { [] }
    func listTrashed() async throws -> [Note] { [] }
    func restore(id: UUID) async throws { }
    func purge(id: UUID) async throws { }
}
