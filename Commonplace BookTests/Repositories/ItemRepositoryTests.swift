//
//  ItemRepositoryTests.swift
//  Commonplace BookTests
//
//  Created by Chris Prather on 5/1/25.
//

import XCTest
import Combine
import CoreData
@testable import Commonplace_Book

final class ItemRepositoryTests: XCTestCase {
    // Properties
    var repository: ItemRepository!
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var cancellables = Set<AnyCancellable>()
    
    // Setup
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        repository = ItemRepository(context: context)
    }
    
    // Teardown
    override func tearDown() {
        repository = nil
        context = nil
        persistenceController = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testFetchAllEmptyRepository() {
        // Given
        let expectation = XCTestExpectation(description: "Fetch all items from empty repository")
        
        // When
        repository.fetchAll()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to fetch items: \(error.localizedDescription)")
                    }
                },
                receiveValue: { items in
                    // Then
                    XCTAssertTrue(items.isEmpty, "Repository should be empty")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCreateAndFetchItem() {
        // Given
        let createExpectation = XCTestExpectation(description: "Create new item")
        let fetchExpectation = XCTestExpectation(description: "Fetch created item")
        let title = "Test Item"
        let description = "Test Description"
        let category = "Test Category"
        
        // When creating
        repository.createItem(title: title, description: description, category: category)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to create item: \(error.localizedDescription)")
                    }
                },
                receiveValue: { item in
                    // Then
                    XCTAssertEqual(item.title, title)
                    XCTAssertEqual(item.itemDescription, description)
                    XCTAssertEqual(item.category, category)
                    XCTAssertNotNil(item.id)
                    XCTAssertNotNil(item.timestamp)
                    createExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [createExpectation], timeout: 1.0)
        
        // When fetching
        repository.fetchAll()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to fetch items: \(error.localizedDescription)")
                    }
                },
                receiveValue: { items in
                    // Then
                    XCTAssertEqual(items.count, 1)
                    XCTAssertEqual(items.first?.title, title)
                    XCTAssertEqual(items.first?.itemDescription, description)
                    XCTAssertEqual(items.first?.category, category)
                    fetchExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [fetchExpectation], timeout: 1.0)
    }
    
    func testFetchByCategory() {
        // Given
        let setupExpectation = XCTestExpectation(description: "Setup test data")
        let fetchExpectation = XCTestExpectation(description: "Fetch items by category")
        let categories = ["Work", "Personal", "Work"]
        
        // Create test items with different categories
        let group = DispatchGroup()
        
        for category in categories {
            group.enter()
            repository.createItem(title: "Item \(category)", category: category)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Failed to create item: \(error.localizedDescription)")
                        }
                        group.leave()
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
        
        group.notify(queue: .main) {
            setupExpectation.fulfill()
        }
        
        wait(for: [setupExpectation], timeout: 1.0)
        
        // When
        repository.fetchByCategory("Work")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to fetch items by category: \(error.localizedDescription)")
                    }
                },
                receiveValue: { items in
                    // Then
                    XCTAssertEqual(items.count, 2, "Should find 2 items with category 'Work'")
                    XCTAssertTrue(items.allSatisfy { $0.category == "Work" }, "All items should have category 'Work'")
                    fetchExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [fetchExpectation], timeout: 1.0)
    }
    
    func testUpdateItem() {
        // Given
        let createExpectation = XCTestExpectation(description: "Create item to update")
        let updateExpectation = XCTestExpectation(description: "Update item")
        let fetchExpectation = XCTestExpectation(description: "Fetch updated item")
        var createdItem: Item?
        
        // Create an item
        repository.createItem(title: "Original Title")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to create item: \(error.localizedDescription)")
                    }
                },
                receiveValue: { item in
                    createdItem = item
                    createExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [createExpectation], timeout: 1.0)
        
        // When
        guard let item = createdItem else {
            XCTFail("Item was not created")
            return
        }
        
        // Update the item
        item.title = "Updated Title"
        repository.update(entity: item)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to update item: \(error.localizedDescription)")
                    }
                },
                receiveValue: { updatedItem in
                    XCTAssertEqual(updatedItem.title, "Updated Title")
                    updateExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [updateExpectation], timeout: 1.0)
        
        // Fetch to verify update
        if let id = item.id {
            repository.fetch(byId: id)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Failed to fetch item: \(error.localizedDescription)")
                        }
                    },
                    receiveValue: { fetchedItem in
                        XCTAssertNotNil(fetchedItem)
                        XCTAssertEqual(fetchedItem?.title, "Updated Title")
                        fetchExpectation.fulfill()
                    }
                )
                .store(in: &cancellables)
            
            wait(for: [fetchExpectation], timeout: 1.0)
        } else {
            XCTFail("Item doesn't have an ID")
        }
    }
    
    func testDeleteItem() {
        // Given
        let createExpectation = XCTestExpectation(description: "Create item to delete")
        let deleteExpectation = XCTestExpectation(description: "Delete item")
        let verifyExpectation = XCTestExpectation(description: "Verify item is deleted")
        var createdItem: Item?
        
        // Create an item
        repository.createItem(title: "Item to Delete")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to create item: \(error.localizedDescription)")
                    }
                },
                receiveValue: { item in
                    createdItem = item
                    createExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [createExpectation], timeout: 1.0)
        
        // When
        guard let item = createdItem else {
            XCTFail("Item was not created")
            return
        }
        
        // Delete the item
        repository.delete(entity: item)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to delete item: \(error.localizedDescription)")
                    } else {
                        deleteExpectation.fulfill()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        wait(for: [deleteExpectation], timeout: 1.0)
        
        // Verify the item is deleted
        repository.fetchAll()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to fetch items: \(error.localizedDescription)")
                    }
                },
                receiveValue: { items in
                    XCTAssertTrue(items.isEmpty, "Repository should be empty after deletion")
                    verifyExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [verifyExpectation], timeout: 1.0)
    }
    
    func testBatchOperations() {
        // Given
        let setupExpectation = XCTestExpectation(description: "Setup test data")
        let batchUpdateExpectation = XCTestExpectation(description: "Batch update items")
        let batchDeleteExpectation = XCTestExpectation(description: "Batch delete items")
        
        // Create test items
        let group = DispatchGroup()
        
        for i in 0..<5 {
            group.enter()
            repository.createItem(title: "Item \(i)", category: "Test")
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Failed to create item: \(error.localizedDescription)")
                        }
                        group.leave()
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
        
        group.notify(queue: .main) {
            setupExpectation.fulfill()
        }
        
        wait(for: [setupExpectation], timeout: 1.0)
        
        // When performing batch update
        let predicate = NSPredicate(format: "category_ == %@", "Test")
        let propertiesToUpdate = ["category_": "Updated Category"]
        
        repository.batchUpdate(propertiesToUpdate: propertiesToUpdate, predicate: predicate)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to batch update items: \(error.localizedDescription)")
                    }
                },
                receiveValue: { count in
                    // Then
                    XCTAssertEqual(count, 5, "Should update 5 items")
                    batchUpdateExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [batchUpdateExpectation], timeout: 1.0)
        
        // When performing batch delete
        let deletePredicate = NSPredicate(format: "category_ == %@", "Updated Category")
        
        repository.batchDelete(predicate: deletePredicate)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to batch delete items: \(error.localizedDescription)")
                    }
                },
                receiveValue: { count in
                    // Then
                    XCTAssertEqual(count, 5, "Should delete 5 items")
                    batchDeleteExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [batchDeleteExpectation], timeout: 1.0)
        
        // Verify repository is empty
        let verifyExpectation = XCTestExpectation(description: "Verify repository is empty")
        
        repository.fetchAll()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to fetch items: \(error.localizedDescription)")
                    }
                },
                receiveValue: { items in
                    XCTAssertTrue(items.isEmpty, "Repository should be empty after batch delete")
                    verifyExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [verifyExpectation], timeout: 1.0)
    }
}
