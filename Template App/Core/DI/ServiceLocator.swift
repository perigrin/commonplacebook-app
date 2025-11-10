//
//  ServiceLocator.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import SwiftUI
import Combine
import CoreData

/// A simple service locator for dependency injection
class ServiceLocator {
    /// Shared instance of the service locator
    static let shared = ServiceLocator()
    
    /// Dictionary of services
    private var services = [String: Any]()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Bootstrap all application services
    func bootstrap() {
        // Register persistence controller
        register(PersistenceController.shared, type: PersistenceController.self)
        
        // Register repositories
        let viewContext = PersistenceController.shared.container.viewContext
        let itemRepository = ItemRepository(context: viewContext)
        register(itemRepository, type: ItemRepository.self)
        
        // Register network services
        let networkService = NetworkService()
        register(networkService, type: NetworkService.self)
        
        Logger.info("Service locator bootstrapped successfully", category: .general)
    }
    
    /// Registers a service
    /// - Parameters:
    ///   - service: The service instance
    ///   - type: The type of the service
    func register<T>(_ service: T, type: T.Type) {
        let key = String(describing: type)
        services[key] = service
        Logger.debug("Registered service: \(key)", category: .general)
    }
    
    /// Resolves a service
    /// - Parameter type: The type of the service to resolve
    /// - Returns: The service instance
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }
    
    /// Checks if a service has been registered
    /// - Parameter type: The type of service to check
    /// - Returns: True if the service is registered, false otherwise
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        return services[key] != nil
    }
    
    /// Lists all registered services
    /// - Returns: An array of service names
    func listRegisteredServices() -> [String] {
        return Array(services.keys)
    }
}

/// Protocol for service registrars
protocol ServiceRegistrar {
    /// Registers services with the service locator
    /// - Parameter locator: The service locator to register with
    static func registerServices(with locator: ServiceLocator)
}

/// SwiftUI environment key for the service locator
struct ServiceLocatorKey: EnvironmentKey {
    /// Default value
    static let defaultValue = ServiceLocator.shared
}

/// Environment extension for the service locator
extension EnvironmentValues {
    /// Service locator environment value
    var serviceLocator: ServiceLocator {
        get { self[ServiceLocatorKey.self] }
        set { self[ServiceLocatorKey.self] = newValue }
    }
}

/// Property wrapper for injecting dependencies
@propertyWrapper
struct Inject<T> {
    /// The wrapped value
    var wrappedValue: T
    
    /// Initializes the property wrapper
    /// - Parameter type: The type to inject
    init(_ type: T.Type) {
        guard let service = ServiceLocator.shared.resolve(type) else {
            let typeName = String(describing: type)
            let registered = ServiceLocator.shared.listRegisteredServices().joined(separator: ", ")
            Logger.error("DI Error: No service of type '\(typeName)' registered. Registered services: [\(registered)]", category: .general)
            fatalError("No service of type \(type) registered with the ServiceLocator. Check logs for registered services.")
        }
        self.wrappedValue = service
    }
}

/// Wrapper class for lazy dependency resolution
final class InjectedService<T> {
    private var _value: T?
    let type: T.Type
    
    init(_ type: T.Type) {
        self.type = type
    }
    
    var value: T {
        if _value == nil {
            guard let service = ServiceLocator.shared.resolve(type) else {
                let typeName = String(describing: type)
                let registered = ServiceLocator.shared.listRegisteredServices().joined(separator: ", ")
                Logger.error("DI Error: No service of type '\(typeName)' registered. Registered services: [\(registered)]", category: .general)
                fatalError("No service of type \(type) registered with the ServiceLocator. Check logs for registered services.")
            }
            _value = service
        }
        return _value!
    }
}

/// Property wrapper for lazily injecting dependencies
@propertyWrapper
struct LazyInject<T> {
    private let injector: InjectedService<T>
    
    var wrappedValue: T {
        injector.value
    }
    
    init(_ type: T.Type) {
        self.injector = InjectedService(type)
    }
}

/// SwiftUI view extension for injecting dependencies
extension View {
    /// Injects a service into the environment
    /// - Parameter type: The type of the service to inject
    /// - Returns: The view with the injected service
    @ViewBuilder
    func inject<T: ObservableObject>(_ type: T.Type) -> some View {
        if let service = ServiceLocator.shared.resolve(type) {
            self.environmentObject(service)
        } else {
            self
        }
    }
}
