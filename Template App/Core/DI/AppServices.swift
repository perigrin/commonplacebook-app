//
//  AppServices.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import CoreData

/// Service registrar for app services
class AppServices: ServiceRegistrar {
    /// Registers all app services with the service locator
    /// - Parameter locator: The service locator to register with
    static func registerServices(with locator: ServiceLocator) {
        // Register persistence service
        let persistenceController = PersistenceController.shared
        locator.register(persistenceController, type: PersistenceController.self)
        
        // Register repositories
        let itemRepository = ItemRepository(context: persistenceController.container.viewContext)
        locator.register(itemRepository, type: ItemRepository.self)
        
        // Register network service
        let networkService = NetworkService.shared
        locator.register(networkService, type: NetworkServiceProtocol.self)
        
        // Register security manager
        let securityManager = SecurityManager.shared
        locator.register(securityManager, type: SecurityManager.self)
        
        Logger.info("App services registered", category: .general)
    }
}

/// Extension for bootstrapping the application
extension ServiceLocator {
    /// Bootstraps the application services with app services
    func bootstrapAppServices() {
        // Register app services
        AppServices.registerServices(with: self)
        
        Logger.info("Application services bootstrapped", category: .general)
    }
}
