//
//  Item+CoreDataProperties.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//
//

import Foundation
import CoreData

extension Item {
    
    @NSManaged public var id_: NSUUID?
    @NSManaged public var title_: String?
    @NSManaged public var itemDescription_: String?
    @NSManaged public var category_: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var tags: NSSet?
    
    // Note: Commented out to avoid duplicate declarations
    // These properties are likely declared elsewhere
    /*
    public var title: String {
        get { return title_ ?? "" }
        set { title_ = newValue }
    }
    
    public var itemDescription: String {
        get { return itemDescription_ ?? "" }
        set { itemDescription_ = newValue }
    }
    
    public var category: String {
        get { return category_ ?? "" }
        set { category_ = newValue }
    }
    */
}

// MARK: - Generated accessors for tags
extension Item {
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}

// MARK: - Identifiable Conformance
extension Item: Identifiable {
    public var id: UUID? {
        get { return id_ as UUID? }
        set { id_ = newValue as UUID? as NSUUID? }
    }
}
