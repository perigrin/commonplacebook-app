//
//  ItemRepository.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import Combine
import CoreData

/// Repository for managing Item entities in Core Data
class ItemRepository: CoreDataRepository {
    typealias Entity = Item
    
    /// The managed object context
    let context: NSManagedObjectContext
    
    /// Initializes the repository with a context
    /// - Parameter context: The managed object context to use
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Fetches all items
    /// - Returns: A publisher that emits an array of items or an error
    func fetchAll() -> AnyPublisher<[Item], Error> {
        let request = Item.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)]
        
        return Future<[Item], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.fetchFailed(NSError())))
                return
            }
            
            self.context.perform {
                do {
                    let items = try self.context.fetch(request)
                    promise(.success(items))
                } catch {
                    Logger.error("Failed to fetch items: \(error.localizedDescription)", category: .database)
                    promise(.failure(RepositoryError.fetchFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Fetches items with a predicate
    /// - Parameter predicate: The predicate to filter items
    /// - Returns: A publisher that emits an array of items or an error
    func fetch(withPredicate predicate: NSPredicate) -> AnyPublisher<[Item], Error> {
        let request = Item.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)]
        
        return Future<[Item], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.fetchFailed(NSError())))
                return
            }
            
            self.context.perform {
                do {
                    let items = try self.context.fetch(request)
                    promise(.success(items))
                } catch {
                    Logger.error("Failed to fetch items with predicate: \(error.localizedDescription)", category: .database)
                    promise(.failure(RepositoryError.fetchFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Fetches an item by ID
    /// - Parameter id: The item ID
    /// - Returns: A publisher that emits the item or an error
    func fetch(byId id: UUID) -> AnyPublisher<Item?, Error> {
        let predicate = NSPredicate(format: "id_ == %@", id as CVarArg)
        
        return fetch(withPredicate: predicate)
            .map { items -> Item? in
                return items.first
            }
            .eraseToAnyPublisher()
    }
    
    /// Fetches items by category
    /// - Parameter category: The category to filter by
    /// - Returns: A publisher that emits an array of items or an error
    func fetchByCategory(_ category: String) -> AnyPublisher<[Item], Error> {
        let predicate = NSPredicate(format: "category_ == %@", category)
        return fetch(withPredicate: predicate)
    }
    
    /// Fetches completed items
    /// - Returns: A publisher that emits an array of completed items or an error
    func fetchCompleted() -> AnyPublisher<[Item], Error> {
        let predicate = NSPredicate(format: "isCompleted == %@", NSNumber(value: true))
        return fetch(withPredicate: predicate)
    }
    
    /// Fetches incomplete items
    /// - Returns: A publisher that emits an array of incomplete items or an error
    func fetchIncomplete() -> AnyPublisher<[Item], Error> {
        let predicate = NSPredicate(format: "isCompleted == %@", NSNumber(value: false))
        return fetch(withPredicate: predicate)
    }
    
    /// Saves a new item
    /// - Parameter entity: The item to save
    /// - Returns: A publisher that emits the saved item or an error
    func save(entity: Item) -> AnyPublisher<Item, Error> {
        return Future<Item, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.saveFailed(NSError())))
                return
            }
            
            self.context.perform {
                do {
                    try self.context.save()
                    promise(.success(entity))
                } catch {
                    Logger.error("Failed to save item: \(error.localizedDescription)", category: .database)
                    promise(.failure(RepositoryError.saveFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Creates and saves a new item with the specified properties
    /// - Parameters:
    ///   - title: The item title
    ///   - description: The item description
    ///   - category: The item category
    /// - Returns: A publisher that emits the saved item or an error
    func createItem(title: String, description: String = "", category: String = "Uncategorized") -> AnyPublisher<Item, Error> {
        return Future<Item, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.saveFailed(NSError())))
                return
            }
            
            self.context.perform {
                let item = ItemFactory.create(
                    in: self.context,
                    title: title,
                    description: description,
                    category: category
                )
                
                do {
                    try self.context.save()
                    promise(.success(item))
                } catch {
                    Logger.error("Failed to create item: \(error.localizedDescription)", category: .database)
                    promise(.failure(RepositoryError.saveFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Updates an existing item
    /// - Parameter entity: The item to update
    /// - Returns: A publisher that emits the updated item or an error
    func update(entity: Item) -> AnyPublisher<Item, Error> {
        return Future<Item, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.updateFailed(NSError())))
                return
            }
            
            self.context.perform {
                do {
                    try self.context.save()
                    promise(.success(entity))
                } catch {
                    Logger.error("Failed to update item: \(error.localizedDescription)", category: .database)
                    promise(.failure(RepositoryError.updateFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Marks an item as completed
    /// - Parameter entity: The item to mark as completed
    /// - Returns: A publisher that emits the updated item or an error
    func markAsCompleted(entity: Item) -> AnyPublisher<Item, Error> {
        entity.isCompleted = true
        return update(entity: entity)
    }
    
    /// Marks an item as incomplete
    /// - Parameter entity: The item to mark as incomplete
    /// - Returns: A publisher that emits the updated item or an error
    func markAsIncomplete(entity: Item) -> AnyPublisher<Item, Error> {
        entity.isCompleted = false
        return update(entity: entity)
    }
    
    /// Deletes an item
    /// - Parameter entity: The item to delete
    /// - Returns: A publisher that emits a completion or an error
    func delete(entity: Item) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.deleteFailed(NSError())))
                return
            }
            
            self.context.perform {
                self.context.delete(entity)
                
                do {
                    try self.context.save()
                    promise(.success(()))
                } catch {
                    Logger.error("Failed to delete item: \(error.localizedDescription)", category: .database)
                    promise(.failure(RepositoryError.deleteFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Performs a batch update on items
    /// - Parameters:
    ///   - propertiesToUpdate: The properties to update
    ///   - predicate: The predicate to filter items
    /// - Returns: A publisher that emits the number of updated items or an error
    func batchUpdate(propertiesToUpdate: [String: Any], predicate: NSPredicate) -> AnyPublisher<Int, Error> {
        return Future<Int, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.updateFailed(NSError())))
                return
            }
            
            self.context.perform {
                let batchUpdateRequest = NSBatchUpdateRequest(entityName: "Item")
                batchUpdateRequest.predicate = predicate
                batchUpdateRequest.propertiesToUpdate = propertiesToUpdate
                batchUpdateRequest.resultType = .updatedObjectIDsResultType
                
                do {
                    let batchResult = try self.context.execute(batchUpdateRequest) as? NSBatchUpdateResult
                    let objectIDs = batchResult?.result as? [NSManagedObjectID] ?? []
                    
                    // Merge changes into the context
                    let changes = [NSUpdatedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: changes,
                        into: [self.context]
                    )
                    
                    promise(.success(objectIDs.count))
                } catch {
                    Logger.error("Failed to perform batch update: \(error.localizedDescription)", category: .database)
                    promise(.failure(RepositoryError.updateFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// Performs a batch delete on items
    /// - Parameter predicate: The predicate to filter items to delete
    /// - Returns: A publisher that emits the number of deleted items or an error
    func batchDelete(predicate: NSPredicate) -> AnyPublisher<Int, Error> {
        return Future<Int, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.deleteFailed(NSError())))
                return
            }
            
            self.context.perform {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
                fetchRequest.predicate = predicate
                
                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                batchDeleteRequest.resultType = .resultTypeObjectIDs
                
                do {
                    let batchResult = try self.context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                    let objectIDs = batchResult?.result as? [NSManagedObjectID] ?? []
                    
                    // Merge changes into the context
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: changes,
                        into: [self.context]
                    )
                    
                    promise(.success(objectIDs.count))
                } catch {
                    Logger.error("Failed to perform batch delete: \(error.localizedDescription)", category: .database)
                    promise(.failure(RepositoryError.deleteFailed(error)))
                }
            }
        }.eraseToAnyPublisher()
    }
}
