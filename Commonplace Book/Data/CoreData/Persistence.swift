//
//  Persistence.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import CoreData
import Combine
import Foundation

// Forward declaration of Logger to avoid import cycles
enum LoggerProxy {
    static func info(_ message: String, category: String) {
        Logger.info(message, category: Logger.Category(rawValue: category) ?? .general)
    }
    
    static func error(_ message: String, category: String) {
        Logger.error(message, category: Logger.Category(rawValue: category) ?? .general)
    }
    
    static func critical(_ message: String, category: String) {
        Logger.critical(message, category: Logger.Category(rawValue: category) ?? .general)
    }
}

/// PersistenceController manages the Core Data stack for the application
actor PersistenceController {
    /// Shared instance of the persistence controller
    static let shared = PersistenceController()

    /// Notification name for when context is saved
    static let didSaveContextNotification = Notification.Name("PersistenceController.didSaveContext")
    
    /// Preview instance for SwiftUI previews with sample data
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data
        for i in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date().addingTimeInterval(Double(i) * -86400) // Each item 1 day apart
            newItem.id = UUID()
        }
        
        // Save the context
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            LoggerProxy.error("Core Data preview error: \(nsError), \(nsError.userInfo)", category: "database")
        }
        
        return result
    }()

    /// The Core Data persistent container
    let container: NSPersistentContainer

    /// Background context for background operations
    /// Marked nonisolated(unsafe) because NSManagedObjectContext handles its own thread-safety via perform methods
    private nonisolated(unsafe) var _backgroundContext: NSManagedObjectContext?

    /// Get or create the background context
    private nonisolated(unsafe) var backgroundContext: NSManagedObjectContext {
        if let context = _backgroundContext {
            return context
        }
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        _backgroundContext = context
        return context
    }

    /// Creates a new persistence controller
    /// - Parameter inMemory: Whether to use an in-memory store
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Commonplace_Book")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure store options
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }
        
        // Enable history tracking and remote notifications
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Load the persistent stores
        container.loadPersistentStores { [weak self] (storeDescription, error) in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                let errorMessage = self.handlePersistenceError(error)
                LoggerProxy.critical("Core Data initialization error: \(error), \(error.userInfo)", category: "database")
                LoggerProxy.critical("Error details: \(errorMessage)", category: "database")
            }
        }
        
        // Configure the view context
        setupViewContext()
        
        // Setup notifications
        setupNotifications()
    }
    
    /// Saves changes to the Core Data context if needed
    func saveContext() async {
        let context = container.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            NotificationCenter.default.post(name: PersistenceController.didSaveContextNotification, object: nil)
        } catch {
            let nsError = error as NSError
            LoggerProxy.error("Core Data save error: \(nsError), \(nsError.userInfo)", category: "database")
        }
    }
    
    /// Performs an operation in a background context
    /// - Parameter operation: The operation to perform
    func performBackgroundTask<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let result = try operation(self.backgroundContext)
                    
                    // Save if the context has changes
                    if self.backgroundContext.hasChanges {
                        do {
                            try self.backgroundContext.save()
                        } catch {
                            LoggerProxy.error("Failed to save background context: \(error)", category: "database")
                            continuation.resume(throwing: error)
                            return
                        }
                    }
                    
                    continuation.resume(returning: result)
                } catch {
                    LoggerProxy.error("Background operation failed: \(error)", category: "database")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Creates a new object in the specified context
    /// - Parameters:
    ///   - entityName: The name of the entity to create
    ///   - context: The context to create the object in
    /// - Returns: The created object
    func createObject<T: NSManagedObject>(entityName: String, in context: NSManagedObjectContext) -> T {
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)!
        return T(entity: entity, insertInto: context)
    }
    
    /// Deletes all objects of the specified entity
    /// - Parameters:
    ///   - entityName: The name of the entity to delete
    /// - Returns: The number of objects deleted
    func deleteAll(entityName: String) async throws -> Int {
        return try await performBackgroundTask { context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDs = result?.result as? [NSManagedObjectID] ?? []
            
            // Merge changes into the view context
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.container.viewContext])
            
            return objectIDs.count
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up the view context
    private nonisolated func setupViewContext() {
        let viewContext = container.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        viewContext.shouldDeleteInaccessibleFaults = true
    }
    
    /// Sets up notifications for Core Data events
    private nonisolated func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            LoggerProxy.info("Received persistent store remote change notification", category: "database")
            self?.container.viewContext.refreshAllObjects()
        }
    }
    
    /// Handles persistence errors
    /// - Parameter error: The error to handle
    /// - Returns: A user-friendly error message
    private nonisolated func handlePersistenceError(_ error: NSError) -> String {
        switch error.domain {
        case NSCocoaErrorDomain:
            switch error.code {
            case NSPersistentStoreIncompatibleVersionHashError:
                return "The data model version does not match the persistent store."
            case NSMigrationMissingSourceModelError:
                return "The source model for migration is missing."
            case NSMigrationError:
                return "Migration failed."
            case NSPersistentStoreOpenError:
                return "Failed to open the persistent store."
            case NSPersistentStoreIncompleteSaveError:
                return "Incomplete save operation."
            case NSCoreDataError:
                return "Core Data error."
            default:
                return "Unknown Cocoa error: \(error.code)"
            }
        default:
            return "Unknown error domain: \(error.domain)"
        }
    }
}

// MARK: - Core Data Extensions

extension NSManagedObjectContext {
    /// Executes a fetch request with error handling
    /// - Parameter request: The fetch request to execute
    /// - Returns: The fetched objects
    func fetchSafely<T>(_ request: NSFetchRequest<T>) throws -> [T] where T: NSFetchRequestResult {
        do {
            return try self.fetch(request)
        } catch {
            LoggerProxy.error("Fetch error: \(error)", category: "database")
            throw error
        }
    }
    
    /// Performs a safe save operation
    /// - Returns: True if save was successful, false otherwise
    @discardableResult
    func safeSave() -> Bool {
        guard hasChanges else { return true }
        
        do {
            try save()
            return true
        } catch {
            LoggerProxy.error("Context save error: \(error)", category: "database")
            return false
        }
    }
    
    /// Performs a function on the context's queue
    /// - Parameter block: The block to execute
    func performAndWaitSafely<T>(_ block: () throws -> T) rethrows -> T {
        return try self.performAndWait(block)
    }
}

// MARK: - Item Entity Extensions

extension Item {
    /// Creates a new item with the given properties
    /// - Parameters:
    ///   - context: The managed object context
    ///   - timestamp: The timestamp of the item
    /// - Returns: The created item
    @discardableResult
    static func create(in context: NSManagedObjectContext, timestamp: Date = Date()) -> Item {
        let item = Item(context: context)
        item.timestamp = timestamp
        item.id = UUID()
        return item
    }
}
