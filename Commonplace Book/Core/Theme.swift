// ABOUTME: App-wide color theme and styling constants
// ABOUTME: Defines color palette, typography, and spacing for consistent UI

import SwiftUI

/// App theme with color palette and styling constants
enum Theme {

    // MARK: - Color Palette

    /// Color palette based on moody gray-purple scheme
    enum Colors {
        // Base colors from palette
        static let jet = Color(hex: "#2c302e") ?? Color.black           // Dark background
        static let outerSpace = Color(hex: "#474a48") ?? Color.gray    // Medium dark background
        static let battleshipGray = Color(hex: "#909590") ?? Color.gray // Secondary text
        static let grape = Color(hex: "#6829c7") ?? Color.purple         // Accent/primary
        static let spaceCadet = Color(hex: "#34305f") ?? Color.blue    // Alternative dark

        // Semantic colors
        static let primaryBackground = jet
        static let secondaryBackground = outerSpace
        static let tertiaryBackground = spaceCadet
        static let primaryText = Color.white
        static let secondaryText = battleshipGray
        static let accent = grape
        static let separator = battleshipGray.opacity(0.3)

        // Context-specific colors
        static let noteListBackground = jet
        static let noteRowBackground = outerSpace.opacity(0.5)
        static let noteRowHover = outerSpace
        static let detailBackground = primaryBackground
        static let searchBarBackground = outerSpace
    }

    // MARK: - Typography

    enum Typography {
        static let noteTitle = Font.system(size: 15, weight: .semibold)
        static let notePreview = Font.system(size: 13)
        static let noteDate = Font.system(size: 11)
        static let detailTitle = Font.title
        static let detailBody = Font.body
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }
}
