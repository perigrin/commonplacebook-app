//
//  RepositoryProtocol.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import Combine
import CoreData

/// Generic repository protocol defining common CRUD operations
protocol Repository<Entity> {
    /// The entity type that this repository manages
    associatedtype Entity
    
    /// Fetch all entities
    /// - Returns: A publisher that emits an array of entities or an error
    func fetchAll() -> AnyPublisher<[Entity], Error>
    
    /// Fetch an entity by ID
    /// - Parameter id: The unique identifier
    /// - Returns: A publisher that emits the entity or an error
    func fetch(byId id: UUID) -> AnyPublisher<Entity?, Error>
    
    /// Saves a new entity
    /// - Parameter entity: The entity to save
    /// - Returns: A publisher that emits the saved entity or an error
    func save(entity: Entity) -> AnyPublisher<Entity, Error>
    
    /// Updates an existing entity
    /// - Parameter entity: The entity to update
    /// - Returns: A publisher that emits the updated entity or an error
    func update(entity: Entity) -> AnyPublisher<Entity, Error>
    
    /// Deletes an entity
    /// - Parameter entity: The entity to delete
    /// - Returns: A publisher that emits a completion or an error
    func delete(entity: Entity) -> AnyPublisher<Void, Error>
}

/// Core Data specific repository protocol with additional functionality
protocol CoreDataRepository<Entity>: Repository where Entity: NSManagedObject {
    /// The managed object context
    var context: NSManagedObjectContext { get }
    
    /// Fetch entities with a predicate
    /// - Parameter predicate: The predicate to filter entities
    /// - Returns: A publisher that emits an array of entities or an error
    func fetch(withPredicate predicate: NSPredicate) -> AnyPublisher<[Entity], Error>
    
    /// Perform a batch update
    /// - Parameters:
    ///   - propertiesToUpdate: The properties to update
    ///   - predicate: The predicate to filter entities
    /// - Returns: A publisher that emits the number of updated entities or an error
    func batchUpdate(propertiesToUpdate: [String: Any], predicate: NSPredicate) -> AnyPublisher<Int, Error>
    
    /// Perform a batch delete
    /// - Parameter predicate: The predicate to filter entities to delete
    /// - Returns: A publisher that emits the number of deleted entities or an error
    func batchDelete(predicate: NSPredicate) -> AnyPublisher<Int, Error>
}
