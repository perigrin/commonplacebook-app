//
//  Commonplace_BookApp.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import SwiftUI
import Combine
import CoreData

@main
struct Commonplace_BookApp: App {
    /// Initialize the persistence controller
    @LazyInject(PersistenceController.self) private var persistenceController

    /// Initialize the app coordinator
    private let appCoordinator = AppCoordinator()

    /// Initialize the service locator
    private let serviceLocator: ServiceLocator

    /// Initialize the app state
    @StateObject private var appState = AppState()

    /// Initialize biometric authentication service
    @StateObject private var biometricAuth = BiometricAuthService()

    #if os(iOS)
    /// Working Copy service for handling callbacks
    @StateObject private var workingCopyService = WorkingCopyService()
    #endif

    /// Monitor app lifecycle
    @Environment(\.scenePhase) private var scenePhase

    /// Initialize the app
    init() {
        // Bootstrap the service locator
        serviceLocator = ServiceLocator.shared
        serviceLocator.bootstrap()
        serviceLocator.bootstrapAppServices()

        // Configure app appearance
        configureAppearance()

        // Log app launch
        Logger.info("Application launched", category: .general)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                appCoordinator.rootView
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environment(\.serviceLocator, serviceLocator)
                    .environmentObject(appState)
                    .environmentObject(biometricAuth)
                    .onAppear {
                        // Perform any initialization when the app appears
                        Logger.info("App view appeared", category: .ui)
                    }
                    .onDisappear {
                        // Perform any cleanup when the app disappears
                        Logger.info("App view disappeared", category: .ui)
                    }

                // Show lock screen overlay when locked
                if biometricAuth.isLocked {
                    LockScreenView(authService: biometricAuth)
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: biometricAuth.isLocked)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
            #if os(iOS)
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            #endif
        }
    }

    /// Handle scene phase changes for lock/unlock
    private func handleScenePhaseChange(from old: ScenePhase, to new: ScenePhase) {
        Task { @MainActor in
            switch new {
            case .background:
                // Lock when app enters background
                await biometricAuth.lockOnBackground()
                Logger.info("App entered background - locked if biometric auth enabled", category: .security)

            case .active:
                // Attempt to unlock when app becomes active
                if biometricAuth.isLocked {
                    _ = await biometricAuth.unlockOnForeground()
                    Logger.info("App became active - unlock attempted", category: .security)
                }

            case .inactive:
                // App is inactive (e.g., during transition)
                break

            @unknown default:
                break
            }
        }
    }
    
    /// Configure the app appearance
    private func configureAppearance() {
        #if os(iOS)
        // Configure UINavigationBar appearance
        let appearance = UINavigationBar.appearance()
        appearance.tintColor = .systemBlue
        appearance.prefersLargeTitles = true

        // Configure UITableView appearance
        UITableView.appearance().backgroundColor = .systemBackground
        UITableViewCell.appearance().backgroundColor = .systemBackground
        #endif
    }

    #if os(iOS)
    /// Handle incoming URL from Working Copy or other apps
    /// - Parameter url: The incoming URL
    private func handleIncomingURL(_ url: URL) {
        Logger.info("Received URL: \(url.absoluteString)", category: .git)

        Task {
            // Handle Working Copy callbacks
            let handled = await workingCopyService.handleIncomingURL(url)

            if handled {
                Logger.info("URL handled by Working Copy service", category: .git)
            } else {
                Logger.warning("URL not handled: \(url.absoluteString)", category: .general)
            }
        }
    }
    #endif
}

/// Global app state
class AppState: ObservableObject {
    /// Indicates if the user is authenticated
    @Published var isAuthenticated = false
    
    /// The current theme
    @Published var currentTheme: AppTheme = .system
    
    /// The available themes
    enum AppTheme: String, CaseIterable, Identifiable {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
        
        var id: String { self.rawValue }
    }
    
    /// The current app environment
    #if DEBUG
    @Published var environment: AppEnvironment = .development
    #else
    @Published var environment: AppEnvironment = .production
    #endif
    
    /// The available app environments
    enum AppEnvironment: String {
        case development = "Development"
        case staging = "Staging"
        case production = "Production"
    }
    
    /// Initialize the app state
    init() {
        // Load user preferences
        loadPreferences()
    }
    
    /// Load user preferences
    private func loadPreferences() {
        // Load the current theme
        if let themeName = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.appThemeKey),
           let theme = AppTheme(rawValue: themeName) {
            currentTheme = theme
        }
        
        // Check if the user is authenticated
        isAuthenticated = SecurityManager.shared.getStringFromKeychain(forKey: "userAuthToken") != nil
    }
    
    /// Set the current theme
    /// - Parameter theme: The theme to set
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Constants.UserDefaultsKeys.appThemeKey)
    }
    
    /// Log in the user
    /// - Parameter token: The authentication token
    func login(with token: String) {
        SecurityManager.shared.storeStringInKeychain(token, forKey: "userAuthToken")
        isAuthenticated = true
    }
    
    /// Log out the user
    func logout() {
        SecurityManager.shared.deleteFromKeychain(forKey: "userAuthToken")
        isAuthenticated = false
    }
}
