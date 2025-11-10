//
//  HomeViewModelTests.swift
//  Commonplace BookTests
//
//  Created by Chris Prather on 5/1/25.
//

import XCTest
import Combine
import CoreData
@testable import Commonplace_Book

final class HomeViewModelTests: XCTestCase {
    // Properties
    var viewModel: HomeViewModel!
    var mockRepository: MockItemRepository!
    var cancellables = Set<AnyCancellable>()
    
    // Setup
    override func setUp() {
        super.setUp()
        mockRepository = MockItemRepository()
        viewModel = HomeViewModel(itemRepository: mockRepository)
    }
    
    // Teardown
    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testLoadItemsSuccess() {
        // Given
        let expectation = XCTestExpectation(description: "Items loaded")
        let testItems = createTestItems(count: 3)
        mockRepository.itemsToReturn = testItems
        
        // When
        viewModel.onAppear()
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.items.count, 3)
            XCTAssertFalse(self.viewModel.isLoading)
            XCTAssertNil(self.viewModel.errorMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLoadItemsFailure() {
        // Given
        let expectation = XCTestExpectation(description: "Error loading items")
        let testError = ItemRepositoryError.fetchFailed(NSError(domain: "Test", code: 0, userInfo: nil))
        mockRepository.errorToReturn = testError
        
        // When
        viewModel.onAppear()
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.viewModel.items.isEmpty)
            XCTAssertFalse(self.viewModel.isLoading)
            XCTAssertNotNil(self.viewModel.errorMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFilterModeAll() {
        // Given
        let expectation = XCTestExpectation(description: "Filter by all")
        let testItems = createTestItems(count: 5)
        mockRepository.itemsToReturn = testItems
        
        // When
        viewModel.setFilterMode(.all)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.items.count, 5)
            XCTAssertEqual(self.viewModel.filterMode, .all)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFilterModeCompleted() {
        // Given
        let expectation = XCTestExpectation(description: "Filter by completed")
        let completedItems = createTestItems(count: 2, completed: true)
        mockRepository.itemsToReturn = completedItems
        
        // When
        viewModel.setFilterMode(.completed)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.items.count, 2)
            XCTAssertEqual(self.viewModel.filterMode, .completed)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFilterModeIncomplete() {
        // Given
        let expectation = XCTestExpectation(description: "Filter by incomplete")
        let incompleteItems = createTestItems(count: 3, completed: false)
        mockRepository.itemsToReturn = incompleteItems
        
        // When
        viewModel.setFilterMode(.incomplete)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.items.count, 3)
            XCTAssertEqual(self.viewModel.filterMode, .incomplete)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSortModeDateDescending() {
        // Given
        let expectation = XCTestExpectation(description: "Sort by date descending")
        let testItems = createTestItems(count: 3, withDifferentDates: true)
        mockRepository.itemsToReturn = testItems
        
        // When
        viewModel.setSortMode(.dateDescending)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let dates = self.viewModel.items.compactMap { $0.timestamp }
            for i in 0..<dates.count - 1 {
                XCTAssertTrue(dates[i] > dates[i + 1], "Items should be sorted by date in descending order")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSortModeDateAscending() {
        // Given
        let expectation = XCTestExpectation(description: "Sort by date ascending")
        let testItems = createTestItems(count: 3, withDifferentDates: true)
        mockRepository.itemsToReturn = testItems
        
        // When
        viewModel.setSortMode(.dateAscending)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let dates = self.viewModel.items.compactMap { $0.timestamp }
            for i in 0..<dates.count - 1 {
                XCTAssertTrue(dates[i] < dates[i + 1], "Items should be sorted by date in ascending order")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestItems(count: Int, completed: Bool = false, withDifferentDates: Bool = false) -> [Item] {
        let context = createMockContext()
        
        var items: [Item] = []
        for i in 0..<count {
            let item = Item(context: context)
            item.title_ = "Test Item \(i)"
            item.itemDescription_ = "Test Description \(i)"
            item.id_ = UUID() as NSUUID
            item.isCompleted = completed
            
            if withDifferentDates {
                // Each item is one day apart
                item.timestamp = Date().addingTimeInterval(Double(-i * 24 * 60 * 60))
            } else {
                item.timestamp = Date()
            }
            
            items.append(item)
        }
        
        return items
    }
    
    private func createMockContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "Commonplace_Book")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load persistent stores: \(String(describing: error))")
        }
        
        return container.viewContext
    }
}

// MARK: - Mock Repository

class MockItemRepository: ItemRepository {
    var itemsToReturn: [Item] = []
    var errorToReturn: Error?
    
    override func fetchAll() -> AnyPublisher<[Item], Error> {
        if let error = errorToReturn {
            return Fail(error: error).eraseToAnyPublisher()
        }
        return Just(itemsToReturn).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    override func fetch(withPredicate predicate: NSPredicate) -> AnyPublisher<[Item], Error> {
        if let error = errorToReturn {
            return Fail(error: error).eraseToAnyPublisher()
        }
        return Just(itemsToReturn).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    override func fetchCompleted() -> AnyPublisher<[Item], Error> {
        if let error = errorToReturn {
            return Fail(error: error).eraseToAnyPublisher()
        }
        return Just(itemsToReturn).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    override func fetchIncomplete() -> AnyPublisher<[Item], Error> {
        if let error = errorToReturn {
            return Fail(error: error).eraseToAnyPublisher()
        }
        return Just(itemsToReturn).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    override func createItem(title: String, description: String = "", category: String = "Uncategorized") -> AnyPublisher<Item, Error> {
        if let error = errorToReturn {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        if let item = itemsToReturn.first {
            return Just(item).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        return Fail(error: ItemRepositoryError.invalidEntity).eraseToAnyPublisher()
    }
}
