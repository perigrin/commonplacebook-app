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

    private let noteService: NoteService
    private let embeddingService: EmbeddingServiceProtocol
    private let searchEngine: VectorSearchEngineProtocol
    private let listViewModel: NoteListViewModel
    private let searchViewModel: SearchViewModel

    /// The root view of the application
    var rootView: some View {
        EnhancedNoteListView(
            listViewModel: listViewModel,
            searchViewModel: searchViewModel,
            appCoordinator: self
        )
    }

    // MARK: - Initialization

    @MainActor
    init() {
        // Initialize note repository with persistent file system storage
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let notesDirectory = documentsDirectory.appendingPathComponent("Notes")
        let noteRepository = FileSystemNoteRepository(directory: notesDirectory)

        // Initialize embedding service for vector search
        self.embeddingService = EmbeddingService()

        // Initialize vector search engine
        self.searchEngine = VectorSearchEngine(embeddingService: embeddingService)

        // Initialize note service that coordinates repository and search indexing
        self.noteService = NoteService(
            repository: noteRepository,
            searchEngine: searchEngine,
            embeddingService: embeddingService
        )

        // Initialize view models with note service and repository
        self.listViewModel = NoteListViewModel(noteService: noteService, repository: noteRepository, metadataCollector: MetadataCollector())
        self.searchViewModel = SearchViewModel(searchEngine: searchEngine, noteService: noteService, repository: noteRepository)

        setupDependencies()
        configureAppearance()

        // Load and index existing notes
        Task {
            await indexExistingNotes()
        }
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
    
    // MARK: - Search Indexing

    /// Index a single note in the vector search engine
    /// - Parameter noteId: UUID of the note to index
    func indexNote(id noteId: UUID) async {
        do {
            // Read note from note service
            guard let note = try await noteService.read(id: noteId) else {
                Logger.warning("Note \(noteId) not found for indexing", category: .database)
                return
            }

            // Generate embedding for note content
            let embedding = try await embeddingService.generateEmbedding(for: note.content)

            // Index in search engine
            try await searchEngine.indexNote(id: note.id, embedding: embedding)

            Logger.info("Indexed note \(noteId)", category: .database)
        } catch {
            Logger.error("Failed to index note \(noteId): \(error.localizedDescription)", category: .database)
        }
    }

    /// Index all existing notes in the vector search engine on app startup
    /// Note: Individual notes created during app runtime are indexed automatically by NoteService
    private func indexExistingNotes() async {
        do {
            let notes = try await noteService.list()
            Logger.info("Indexing \(notes.count) existing notes on startup", category: .database)

            // Index each existing note using the NoteService's indexing logic
            // This ensures notes created outside the app or before indexing was added are searchable
            for note in notes {
                // Re-create each note through the service to trigger indexing
                // This is a one-time operation on startup
                do {
                    _ = try await noteService.update(note: note)
                } catch {
                    Logger.error("Failed to index note \(note.id): \(error.localizedDescription)", category: .database)
                }
            }

            Logger.info("Finished indexing notes - new notes will be indexed automatically", category: .database)
        } catch {
            Logger.error("Failed to load notes for indexing: \(error.localizedDescription)", category: .database)
        }
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
