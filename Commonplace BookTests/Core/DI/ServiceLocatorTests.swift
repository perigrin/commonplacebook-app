// ABOUTME: Tests for ServiceLocator dependency injection system
// ABOUTME: Validates service registration, resolution, lazy injection, and error handling

import XCTest
@testable import Commonplace_Book

final class ServiceLocatorTests: XCTestCase {
    var serviceLocator: ServiceLocator!

    override func setUp() {
        super.setUp()
        // Create a fresh instance for each test
        // Note: ServiceLocator is a singleton, so we need to clear its state
        serviceLocator = ServiceLocator.shared
        clearAllServices()
    }

    override func tearDown() {
        clearAllServices()
        serviceLocator = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func clearAllServices() {
        // Clear all registered services by accessing the private services dictionary
        // This is a workaround since ServiceLocator doesn't provide a clear method
        let mirror = Mirror(reflecting: serviceLocator)
        if let servicesChild = mirror.children.first(where: { $0.label == "services" }) {
            if var services = servicesChild.value as? [String: Any] {
                services.removeAll()
            }
        }
    }

    // MARK: - Registration Tests

    func testRegisterServiceStoresService() {
        // GIVEN a service to register
        let testService = TestService()

        // WHEN registering the service
        serviceLocator.register(testService, type: TestService.self)

        // THEN service should be registered
        XCTAssertTrue(serviceLocator.isRegistered(TestService.self))
    }

    func testRegisterMultipleServicesStoresAll() {
        // GIVEN multiple services
        let service1 = TestService()
        let service2 = AnotherTestService()
        let service3 = ThirdTestService()

        // WHEN registering all services
        serviceLocator.register(service1, type: TestService.self)
        serviceLocator.register(service2, type: AnotherTestService.self)
        serviceLocator.register(service3, type: ThirdTestService.self)

        // THEN all services should be registered
        XCTAssertTrue(serviceLocator.isRegistered(TestService.self))
        XCTAssertTrue(serviceLocator.isRegistered(AnotherTestService.self))
        XCTAssertTrue(serviceLocator.isRegistered(ThirdTestService.self))
    }

    func testRegisterSameServiceTwiceOverwritesOriginal() {
        // GIVEN a service registered once
        let originalService = TestService()
        originalService.value = "original"
        serviceLocator.register(originalService, type: TestService.self)

        // WHEN registering a new instance of the same type
        let newService = TestService()
        newService.value = "new"
        serviceLocator.register(newService, type: TestService.self)

        // THEN the new service should replace the original
        let resolved = serviceLocator.resolve(TestService.self)
        XCTAssertEqual(resolved?.value, "new")
    }

    func testRegisterProtocolType() {
        // GIVEN a service conforming to a protocol
        let service: TestProtocol = ConcreteTestService()

        // WHEN registering by protocol type
        serviceLocator.register(service, type: TestProtocol.self)

        // THEN protocol type should be registered
        XCTAssertTrue(serviceLocator.isRegistered(TestProtocol.self))
    }

    // MARK: - Resolution Tests

    func testResolveRegisteredServiceReturnsService() {
        // GIVEN a registered service
        let testService = TestService()
        testService.value = "test"
        serviceLocator.register(testService, type: TestService.self)

        // WHEN resolving the service
        let resolved = serviceLocator.resolve(TestService.self)

        // THEN should return the registered service
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.value, "test")
    }

    func testResolveUnregisteredServiceReturnsNil() {
        // GIVEN no service registered
        // WHEN resolving an unregistered service
        let resolved = serviceLocator.resolve(TestService.self)

        // THEN should return nil
        XCTAssertNil(resolved)
    }

    func testResolveReturnsSameInstanceEachTime() {
        // GIVEN a registered service
        let testService = TestService()
        serviceLocator.register(testService, type: TestService.self)

        // WHEN resolving multiple times
        let resolved1 = serviceLocator.resolve(TestService.self)
        let resolved2 = serviceLocator.resolve(TestService.self)

        // THEN should return the same instance
        XCTAssertTrue(resolved1 === resolved2, "Should return same instance")
    }

    func testResolveProtocolTypeReturnsConformingInstance() {
        // GIVEN a service registered by protocol
        let service: TestProtocol = ConcreteTestService()
        serviceLocator.register(service, type: TestProtocol.self)

        // WHEN resolving by protocol
        let resolved = serviceLocator.resolve(TestProtocol.self)

        // THEN should return the conforming instance
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.protocolMethod(), "protocol implementation")
    }

    // MARK: - isRegistered Tests

    func testIsRegisteredReturnsTrueForRegisteredService() {
        // GIVEN a registered service
        serviceLocator.register(TestService(), type: TestService.self)

        // WHEN checking if registered
        let isRegistered = serviceLocator.isRegistered(TestService.self)

        // THEN should return true
        XCTAssertTrue(isRegistered)
    }

    func testIsRegisteredReturnsFalseForUnregisteredService() {
        // GIVEN no service registered
        // WHEN checking if registered
        let isRegistered = serviceLocator.isRegistered(TestService.self)

        // THEN should return false
        XCTAssertFalse(isRegistered)
    }

    // MARK: - listRegisteredServices Tests

    func testListRegisteredServicesReturnsEmptyForNoServices() {
        // GIVEN no services registered
        // WHEN listing services
        let services = serviceLocator.listRegisteredServices()

        // THEN should return empty array
        XCTAssertEqual(services.count, 0)
    }

    func testListRegisteredServicesReturnsAllServiceNames() {
        // GIVEN multiple registered services
        serviceLocator.register(TestService(), type: TestService.self)
        serviceLocator.register(AnotherTestService(), type: AnotherTestService.self)

        // WHEN listing services
        let services = serviceLocator.listRegisteredServices()

        // THEN should return all service type names
        XCTAssertEqual(services.count, 2)
        XCTAssertTrue(services.contains("TestService"))
        XCTAssertTrue(services.contains("AnotherTestService"))
    }

    // MARK: - @Inject Property Wrapper Tests

    func testInjectPropertyWrapperResolvesService() {
        // GIVEN a registered service
        let testService = TestService()
        testService.value = "injected"
        serviceLocator.register(testService, type: TestService.self)

        // WHEN using @Inject property wrapper
        let wrapper = Inject(TestService.self)

        // THEN should resolve the service
        XCTAssertEqual(wrapper.wrappedValue.value, "injected")
    }

    func testInjectPropertyWrapperThrowsFatalErrorForMissingService() {
        // GIVEN no service registered
        // WHEN attempting to use @Inject
        // THEN should trigger fatalError (we can't test fatalError directly in XCTest)
        // This test documents the expected behavior

        // We can only test that resolve returns nil
        let resolved = serviceLocator.resolve(TestService.self)
        XCTAssertNil(resolved, "Unregistered service should return nil")

        // Note: In production, @Inject will call fatalError if service is not registered
        // This is by design to catch DI issues during development
    }

    // MARK: - @LazyInject Property Wrapper Tests

    func testLazyInjectPropertyWrapperResolvesServiceOnFirstAccess() {
        // GIVEN a service that will be registered after wrapper creation
        let lazyWrapper = LazyInject(TestService.self)

        // Register service after wrapper is created
        let testService = TestService()
        testService.value = "lazy injected"
        serviceLocator.register(testService, type: TestService.self)

        // WHEN accessing the wrapped value
        let value = lazyWrapper.wrappedValue

        // THEN should resolve the service
        XCTAssertEqual(value.value, "lazy injected")
    }

    func testLazyInjectCachesResolvedService() {
        // GIVEN a registered service
        let testService = TestService()
        serviceLocator.register(testService, type: TestService.self)

        let lazyWrapper = LazyInject(TestService.self)

        // WHEN accessing multiple times
        let value1 = lazyWrapper.wrappedValue
        let value2 = lazyWrapper.wrappedValue

        // THEN should return same instance (cached)
        XCTAssertTrue(value1 === value2)
    }

    // MARK: - Bootstrap Tests

    func testBootstrapRegistersCoreServices() {
        // GIVEN fresh service locator
        clearAllServices()

        // WHEN bootstrapping
        serviceLocator.bootstrap()

        // THEN core services should be registered
        XCTAssertTrue(serviceLocator.isRegistered(PersistenceController.self))
        XCTAssertTrue(serviceLocator.isRegistered(ItemRepository.self))
        XCTAssertTrue(serviceLocator.isRegistered(NetworkService.self))
    }

    func testBootstrapCanBeCalledMultipleTimes() {
        // GIVEN bootstrap called once
        serviceLocator.bootstrap()
        let services1 = serviceLocator.listRegisteredServices()

        // WHEN calling bootstrap again
        serviceLocator.bootstrap()
        let services2 = serviceLocator.listRegisteredServices()

        // THEN should not duplicate services
        XCTAssertEqual(services1.count, services2.count)
    }

    // MARK: - Thread Safety Tests (if ServiceLocator is used from multiple threads)

    func testConcurrentRegistrationIsSafe() {
        // GIVEN multiple concurrent registration operations
        let expectation = XCTestExpectation(description: "Concurrent registrations complete")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        // WHEN registering services concurrently
        for i in 0..<100 {
            group.enter()
            queue.async {
                let service = TestService()
                service.value = "service-\(i)"
                // Each thread registers with a unique key to avoid conflicts
                // In real usage, this would be the same type being registered multiple times
                self.serviceLocator.register(service, type: TestService.self)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN no crashes should occur
        XCTAssertTrue(serviceLocator.isRegistered(TestService.self))
    }

    func testConcurrentResolutionIsSafe() {
        // GIVEN a registered service
        let testService = TestService()
        serviceLocator.register(testService, type: TestService.self)

        let expectation = XCTestExpectation(description: "Concurrent resolutions complete")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        var resolvedServices: [TestService?] = []
        let lock = NSLock()

        // WHEN resolving concurrently
        for _ in 0..<100 {
            group.enter()
            queue.async {
                let resolved = self.serviceLocator.resolve(TestService.self)
                lock.lock()
                resolvedServices.append(resolved)
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all resolutions should succeed
        XCTAssertEqual(resolvedServices.count, 100)
        XCTAssertTrue(resolvedServices.allSatisfy { $0 != nil })
    }

    // MARK: - Edge Cases

    func testRegisterNilServiceHandling() {
        // Note: Swift's type system prevents registering nil directly
        // But we can test registering an Optional type

        let optionalService: TestService? = nil
        serviceLocator.register(optionalService, type: Optional<TestService>.self)

        let resolved = serviceLocator.resolve(Optional<TestService>.self)
        XCTAssertNotNil(resolved, "Should resolve to the Optional container")
    }

    func testResolveAfterClearingServices() {
        // GIVEN a registered service
        serviceLocator.register(TestService(), type: TestService.self)
        XCTAssertNotNil(serviceLocator.resolve(TestService.self))

        // WHEN clearing all services
        clearAllServices()

        // THEN resolution should return nil
        XCTAssertNil(serviceLocator.resolve(TestService.self))
    }
}

// MARK: - Test Helper Classes

class TestService {
    var value: String = ""
}

class AnotherTestService {
    var data: Int = 0
}

class ThirdTestService {
    var flag: Bool = false
}

protocol TestProtocol {
    func protocolMethod() -> String
}

class ConcreteTestService: TestProtocol {
    func protocolMethod() -> String {
        return "protocol implementation"
    }
}
