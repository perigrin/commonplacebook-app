//
//  HomeViewModel.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

import SwiftUI
import CoreData
import Combine


/// ViewModel for the Home screen that manages item-related operations
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Indicates if the view is currently loading data
    @Published var isLoading = false
    
    /// Error message to display to the user
    @Published var errorMessage: String?
    
    /// The items to display
    @Published var items: [Item] = []
    
    /// The current filter mode
    @Published var filterMode: FilterMode = .all
    
    /// The current sort mode
    @Published var sortMode: SortMode = .dateDescending
    
    /// Filter modes for items
    enum FilterMode: String, CaseIterable, Identifiable {
        case all = "All"
        case incomplete = "Incomplete"
        case completed = "Completed"
        
        var id: String { self.rawValue }
    }
    
    /// Sort modes for items
    enum SortMode: String, CaseIterable, Identifiable {
        case dateAscending = "Oldest First"
        case dateDescending = "Newest First"
        case titleAscending = "Title A-Z"
        case titleDescending = "Title Z-A"
        case priority = "Priority"
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Private Properties
    
    /// Repository for item operations
    private let itemRepository: ItemRepository
    
    /// Set of cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initializes the view model with a repository
    /// - Parameter itemRepository: The repository for item operations
    init(itemRepository: ItemRepository = ServiceLocator.shared.resolve(ItemRepository.self)!) {
        self.itemRepository = itemRepository
        setupBindings()
    }
    
    // MARK: - Deinitialization
    
    /// Cleans up resources when the view model is deallocated
    deinit {
        cancellables.forEach { $0.cancel() }
        Logger.debug("HomeViewModel deallocated", category: .ui)
    }
    
    // MARK: - Public Methods
    
    /// Called when the view appears
    func onAppear() {
        Logger.info("HomeViewModel appeared", category: .ui)
        loadItems()
    }
    
    /// Adds a new item to the data store
    /// - Parameter context: The managed object context to use
    @MainActor
    func addItem(in context: NSManagedObjectContext) {
        isLoading = true
        
        itemRepository.createItem(title: "New Item")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadItems()
                }
            )
            .store(in: &cancellables)
    }
    
    /// Deletes items at the specified offsets
    /// - Parameters:
    ///   - offsets: The offsets of the items to delete
    ///   - items: The fetched results containing the items
    ///   - context: The managed object context to use
    @MainActor
    func deleteItems(at offsets: IndexSet, items: FetchedResults<Item>, in context: NSManagedObjectContext) {
        for index in offsets {
            let item = items[index]
            
            itemRepository.delete(entity: item)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                        }
                    },
                    receiveValue: { [weak self] _ in
                        self?.loadItems()
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    /// Toggles the completion status of an item
    /// - Parameter item: The item to toggle
    func toggleItemCompletion(_ item: Item) {
        isLoading = true
        
        let publisher = item.isCompleted ?
            itemRepository.markAsIncomplete(entity: item) :
            itemRepository.markAsCompleted(entity: item)
        
        publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadItems()
                }
            )
            .store(in: &cancellables)
    }
    
    /// Sets the filter mode and refreshes items
    /// - Parameter mode: The filter mode to set
    func setFilterMode(_ mode: FilterMode) {
        filterMode = mode
        loadItems()
    }
    
    /// Sets the sort mode and refreshes items
    /// - Parameter mode: The sort mode to set
    func setSortMode(_ mode: SortMode) {
        sortMode = mode
        loadItems()
    }
    
    /// Refreshes the items
    func refresh() {
        loadItems()
    }
    
    // MARK: - Private Methods
    
    /// Sets up bindings between publishers and subscribers
    private func setupBindings() {
        // Example of how to set up a binding for error handling
        $errorMessage
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .sink { [weak self] _ in
                // Handle error message display logic
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    /// Loads items from the repository
    private func loadItems() {
        isLoading = true
        
        // Determine which publisher to use based on filter mode
        let publisher: AnyPublisher<[Item], Error>
        
        switch filterMode {
        case .all:
            publisher = itemRepository.fetchAll()
        case .completed:
            publisher = itemRepository.fetchCompleted()
        case .incomplete:
            publisher = itemRepository.fetchIncomplete()
        }
        
        publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] items in
                    guard let self = self else { return }
                    
                    // Sort the items based on sort mode
                    var sortedItems = items
                    
                    switch self.sortMode {
                    case .dateAscending:
                        sortedItems.sort { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
                    case .dateDescending:
                        sortedItems.sort { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
                    case .titleAscending:
                        sortedItems.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                    case .titleDescending:
                        sortedItems.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
                    case .priority:
                        sortedItems.sort { $0.priority > $1.priority }
                    }
                    
                    self.items = sortedItems
                }
            )
            .store(in: &cancellables)
    }
}
