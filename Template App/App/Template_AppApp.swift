//
//  Template_AppApp.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

import SwiftUI
import Combine
import CoreData

@main
struct Template_AppApp: App {
    /// Initialize the persistence controller
    @LazyInject(PersistenceController.self) private var persistenceController
    
    /// Initialize the app coordinator
    private let appCoordinator = AppCoordinator()
    
    /// Initialize the service locator
    private let serviceLocator: ServiceLocator
    
    /// Initialize the app state
    @StateObject private var appState = AppState()
    
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
            appCoordinator.rootView
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.serviceLocator, serviceLocator)
                .environmentObject(appState)
                .onAppear {
                    // Perform any initialization when the app appears
                    Logger.info("App view appeared", category: .ui)
                }
                .onDisappear {
                    // Perform any cleanup when the app disappears
                    Logger.info("App view disappeared", category: .ui)
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
