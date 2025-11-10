// ABOUTME: String extension for safe Unicode truncation without splitting grapheme clusters
// ABOUTME: Handles complex emojis and multi-byte characters correctly

import Foundation

extension String {
    /// Safely truncates a string to max length without splitting Unicode characters or grapheme clusters
    /// - Parameter maxLength: Maximum number of characters (grapheme clusters) to include
    /// - Returns: Truncated string that safely handles complex emojis and Unicode
    func truncated(to maxLength: Int) -> String {
        guard self.count > maxLength else { return self }

        // Iterate through grapheme clusters to avoid splitting complex emojis
        var truncated = ""
        var characterCount = 0

        for grapheme in self {
            if characterCount >= maxLength { break }
            truncated.append(grapheme)
            characterCount += 1
        }

        return truncated
    }
}
