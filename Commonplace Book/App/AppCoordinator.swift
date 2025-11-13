//
//  AppCoordinator.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import SwiftUI
// Import platform-specific frameworks conditionally
#if os(iOS) || os(tvOS)
import UIKit
#endif
import CoreData
import Combine

/// AppCoordinator is responsible for managing app navigation and coordinating between different features
class AppCoordinator: ObservableObject {

    // MARK: - Properties

    private let noteRepository: NoteRepository
    private let searchEngine: VectorSearchEngineProtocol
    private let listViewModel: NoteListViewModel
    private let searchViewModel: SearchViewModel

    /// The root view of the application
    var rootView: some View {
        EnhancedNoteListView(
            listViewModel: listViewModel,
            searchViewModel: searchViewModel
        )
    }

    // MARK: - Initialization

    @MainActor
    init() {
        // Initialize note repository (using InMemoryRepository for MVP)
        // TODO: Replace with FileSystemNoteRepository or CRDTNoteRepository for production
        self.noteRepository = InMemoryNoteRepository()

        // Initialize embedding service for vector search
        let embeddingService = EmbeddingService()

        // Initialize vector search engine
        self.searchEngine = VectorSearchEngine(embeddingService: embeddingService)

        // Initialize view models
        self.listViewModel = NoteListViewModel(repository: noteRepository, metadataCollector: MetadataCollector())
        self.searchViewModel = SearchViewModel(searchEngine: searchEngine, repository: noteRepository)

        setupDependencies()
        configureAppearance()
    }

    // MARK: - Setup Methods

    /// Sets up the app dependencies
    private func setupDependencies() {
        // Additional dependency setup if needed
    }
    
    /// Configures global app appearance
    private func configureAppearance() {
        // Set up global appearance like nav bar style, colors, etc.
        #if os(iOS)
        // iOS-specific appearance
        UINavigationBar.appearance().tintColor = .systemBlue
        #endif
    }
    
    // MARK: - Navigation Methods
    
    /// Handles deep links
    func handleDeepLink(_ url: URL) {
        // Add deep link handling logic here
        Logger.info("Deep link received: \(url.absoluteString)", category: .ui)
    }
    
    /// Handles universal links
    func handleUniversalLink(_ userActivity: NSUserActivity) {
        // Add universal link handling logic here
        Logger.info("Universal link received: \(userActivity.activityType)", category: .ui)
    }
    
    /// Handles push notifications
    func handlePushNotification(_ userInfo: [AnyHashable: Any]) {
        // Add push notification handling logic here
        Logger.info("Push notification received", category: .ui)
    }
}
