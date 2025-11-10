//
//  Tag+CoreDataProperties.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//
//

import Foundation
import CoreData
import SwiftUI

extension Tag {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var colorHex: String?
    @NSManaged public var items: NSSet?
    
    // Computed property to get a SwiftUI Color from the hex value
    var color: Color {
        get {
            guard let hex = colorHex else {
                return .gray // Default color
            }
            return Color(hex: hex) ?? .gray
        }
        set {
            colorHex = newValue.toHex
        }
    }
}

// MARK: Generated accessors for items
extension Tag {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: Item)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: Item)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}

// MARK: - Color Extensions for Hex Conversion

extension Color {
    // Initialize a Color from a hex string
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
    
    // Convert a Color to a hex string
    var toHex: String {
        #if os(iOS)
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }
        #else
        guard let components = NSColor(self).cgColor.components else {
            return "#000000"
        }
        #endif
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
