//
//  ItemFactory.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import CoreData

/// Factory class for creating Item instances with default values
struct ItemFactory {
    /// Creates a default item
    /// - Parameter context: The managed object context
    /// - Returns: A new Item instance
    static func createDefault(in context: NSManagedObjectContext) -> Item {
        let item = Item(context: context)
        item.timestamp = Date()
        item.id_ = UUID() as NSUUID
        item.title_ = "New Item"
        item.itemDescription_ = ""
        item.category_ = "Uncategorized"
        return item
    }
    
    /// Creates an item with the specified properties
    /// - Parameters:
    ///   - context: The managed object context
    ///   - title: The item title
    ///   - description: The item description
    ///   - category: The item category
    /// - Returns: A new Item instance
    static func create(
        in context: NSManagedObjectContext,
        title: String,
        description: String = "",
        category: String = "Uncategorized"
    ) -> Item {
        let item = Item(context: context)
        item.timestamp = Date()
        item.id_ = UUID() as NSUUID
        item.title_ = title
        item.itemDescription_ = description
        item.category_ = category
        return item
    }
    
    /// Creates multiple items for testing purposes
    /// - Parameters:
    ///   - context: The managed object context
    ///   - count: The number of items to create
    /// - Returns: An array of new Item instances
    static func createSampleItems(in context: NSManagedObjectContext, count: Int) -> [Item] {
        var items: [Item] = []
        
        let titles = [
            "Complete project presentation",
            "Review design mockups",
            "Schedule team meeting",
            "Research new technologies",
            "Update documentation",
            "Prepare weekly report",
            "Fix critical bugs",
            "Implement new feature",
            "Update dependencies",
            "Refactor legacy code"
        ]
        
        let descriptions = [
            "Finalize slides and practice delivery",
            "Provide feedback on UI/UX improvements",
            "Coordinate with all team members for availability",
            "Evaluate potential tools for upcoming projects",
            "Ensure all features are properly documented",
            "Compile stats and metrics for stakeholders",
            "Address high-priority issues in the bug tracker",
            "Build and test according to specifications",
            "Update all frameworks to their latest versions",
            "Improve code quality and maintainability"
        ]
        
        let categories = [
            "Work",
            "Personal",
            "Urgent",
            "Long-term",
            "Completed"
        ]
        
        for i in 0..<min(count, titles.count) {
            let item = Item(context: context)
            item.timestamp = Date().addingTimeInterval(Double(-i * 3600 * 24))
            item.id_ = UUID() as NSUUID
            item.title_ = titles[i]
            item.itemDescription_ = descriptions[i]
            item.category_ = categories[i % categories.count]
            items.append(item)
        }
        
        // If we need more items than our predefined list
        if count > titles.count {
            for i in titles.count..<count {
                let item = Item(context: context)
                item.timestamp = Date().addingTimeInterval(Double(-i * 3600 * 24))
                item.id_ = UUID() as NSUUID
                item.title_ = "Sample Item \(i + 1)"
                item.itemDescription_ = "This is a sample item description"
                item.category_ = categories[i % categories.count]
                items.append(item)
            }
        }
        
        return items
    }
}
