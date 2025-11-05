//
//  Item+Extensions.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import CoreData
import SwiftUI

/// Extension on Item entity to add additional functionality
extension Item {
    // We've moved the id property to the CoreDataProperties file to fix the Identifiable conformance
    
    /// Computed property for item title for cleaner access
    var title: String {
        get { return title_ ?? "Untitled Item" }
        set { title_ = newValue }
    }
    
    /// Computed property for item description for cleaner access
    var itemDescription: String {
        get { return itemDescription_ ?? "" }
        set { itemDescription_ = newValue }
    }
    
    /// Computed property for item category for cleaner access
    var category: String {
        get { return category_ ?? "Uncategorized" }
        set { category_ = newValue }
    }
    
    /// Returns a formatted date string
    var formattedDate: String {
        guard let timestamp = timestamp else {
            return "No date"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Returns the age of the item in a human-readable format
    var age: String {
        guard let timestamp = timestamp else {
            return "Unknown"
        }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: timestamp, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1 year ago" : "\(year) years ago"
        } else if let month = components.month, month > 0 {
            return month == 1 ? "1 month ago" : "\(month) months ago"
        } else if let day = components.day, day > 0 {
            return day == 1 ? "1 day ago" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 minute ago" : "\(minute) minutes ago"
        } else {
            return "Just now"
        }
    }
    
    /// A color representation for the item based on its category
    var categoryColor: Color {
        switch category.lowercased() {
        case "personal":
            return .blue
        case "work":
            return .green
        case "urgent":
            return .red
        case "completed":
            return .gray
        default:
            return .purple
        }
    }
    
    /// Returns the associated tags as an array
    var tagArray: [Tag] {
        let set = tags as? Set<Tag> ?? []
        return set.sorted { 
            ($0.name ?? "") < ($1.name ?? "") 
        }
    }
    
    /// Adds a tag to the item
    /// - Parameter tag: The tag to add
    func addTag(_ tag: Tag) {
        addToTags(tag)
    }
    
    /// Removes a tag from the item
    /// - Parameter tag: The tag to remove
    func removeTag(_ tag: Tag) {
        removeFromTags(tag)
    }
    
    /// Creates a fetch request for Item entities
    /// - Returns: A fetch request for Item entities
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item")
    }
}
