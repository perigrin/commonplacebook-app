// ABOUTME: Service for generating short previews/abstracts from note content
// ABOUTME: Strips markdown syntax, truncates at word boundaries, and adds ellipsis when needed

import Foundation
import NaturalLanguage

/// Service for generating note abstracts/previews
class AbstractGenerator {

    // Maximum input size to prevent memory issues (1MB)
    private let maxInputSize = 1_000_000

    // MARK: - Public Methods

    /// Generate an abstract from note content
    /// - Parameters:
    ///   - content: Full note content (may contain markdown)
    ///   - maxLength: Maximum length of abstract (default: 100)
    /// - Returns: Abstract string, stripped of markdown and truncated if needed
    func generateAbstract(from content: String, maxLength: Int = 100) -> String {
        // Validate max length
        guard maxLength > 0 else { return "" }

        // Handle empty content
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        // Prevent memory issues with huge inputs
        let safeContent = content.count > maxInputSize
            ? String(content.prefix(maxInputSize))
            : content

        // Strip markdown syntax
        let plainText = stripMarkdown(from: safeContent)

        // Normalize whitespace
        let normalized = normalizeWhitespace(plainText)

        // Handle short content
        guard normalized.count > maxLength else {
            return normalized
        }

        // Truncate at word boundary
        return truncateAtWordBoundary(normalized, maxLength: maxLength)
    }

    // MARK: - Private Methods

    /// Strip markdown syntax from text
    /// - Parameter text: Text with markdown
    /// - Returns: Plain text without markdown syntax
    private func stripMarkdown(from text: String) -> String {
        var result = text

        // Use NSRegularExpression for better control and performance
        let patterns: [(String, String)] = [
            // Code blocks (non-greedy, multiline)
            ("```[\\s\\S]*?```", " "),
            // Inline code
            ("`([^`]+)`", "$1"),
            // Links [text](url)
            ("\\[([^\\]]+)\\]\\([^\\)]+\\)", "$1"),
            // Images ![alt](url)
            ("!\\[([^\\]]*)\\]\\([^\\)]+\\)", "$1"),
            // Headers (with multiline support)
            ("(?m)^#{1,6}\\s+", ""),
            // Bold (**text**)
            ("\\*\\*([^*]+?)\\*\\*", "$1"),
            // Bold (__text__) - only at word boundaries to preserve snake_case
            ("\\b__([^_]+?)__\\b", "$1"),
            // Italic (*text*)
            ("\\*([^*\\s][^*]*?)\\*", "$1"),
            // Italic (_text_) - only at word boundaries to preserve snake_case
            ("\\b_([^_\\s][^_]+?)_\\b", "$1"),
            // List markers (multiline)
            ("(?m)^[\\s]*[-*+]\\s+", ""),
            ("(?m)^[\\s]*\\d+\\.\\s+", ""),
            // Blockquotes (multiline)
            ("(?m)^>\\s+", ""),
            // Horizontal rules (multiline)
            ("(?m)^[\\-*_]{3,}\\s*$", ""),
            // Strikethrough
            ("~~([^~]+?)~~", "$1"),
            // HTML tags (simple)
            ("<[^>]+>", ""),
        ]

        for (pattern, replacement) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: range,
                    withTemplate: replacement
                )
            } catch {
                // Continue processing if regex fails
                continue
            }
        }

        return result
    }

    /// Normalize whitespace (collapse multiple spaces/newlines)
    /// - Parameter text: Text with potentially irregular whitespace
    /// - Returns: Text with normalized whitespace
    private func normalizeWhitespace(_ text: String) -> String {
        do {
            // Replace all whitespace sequences with single space
            let regex = try NSRegularExpression(pattern: "\\s+")
            let range = NSRange(text.startIndex..., in: text)
            var result = regex.stringByReplacingMatches(
                in: text,
                range: range,
                withTemplate: " "
            )

            // Trim leading/trailing whitespace
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)

            return result
        } catch {
            // Fallback to simple trim if regex fails
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Truncate text at word boundary
    /// - Parameters:
    ///   - text: Text to truncate
    ///   - maxLength: Maximum length
    /// - Returns: Truncated text with ellipsis
    private func truncateAtWordBoundary(_ text: String, maxLength: Int) -> String {
        // If text fits, return as-is
        guard text.count > maxLength else {
            return text
        }

        // Handle UTF-16 to prevent emoji crashes
        let utf16 = text.utf16
        guard utf16.count > maxLength else {
            return text
        }

        // Find safe truncation point
        let targetIndex = text.utf16.index(text.utf16.startIndex, offsetBy: min(maxLength, text.utf16.count))

        // Convert back to String.Index safely
        guard let stringIndex = targetIndex.samePosition(in: text) else {
            // Fallback: truncate at safe position
            return String(text.prefix(maxLength / 2)) + "..."
        }

        // Search backwards for word boundary
        var truncateAt = stringIndex

        // Use NaturalLanguage tokenizer for proper word boundary detection
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        // Find token containing or before our target
        var foundBoundary = false
        tokenizer.enumerateTokens(in: text.startIndex..<stringIndex) { tokenRange, _ in
            if tokenRange.upperBound <= stringIndex {
                truncateAt = tokenRange.upperBound
                foundBoundary = true
            }
            return true
        }

        // Fallback: search for whitespace
        if !foundBoundary {
            let searchText = String(text[..<stringIndex])
            if let lastSpace = searchText.lastIndex(where: { $0.isWhitespace || $0.isPunctuation }) {
                truncateAt = lastSpace
            }
        }

        // Build truncated string
        var truncated = String(text[..<truncateAt])

        // Remove trailing whitespace/punctuation
        truncated = truncated.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

        return truncated + "..."
    }
}
