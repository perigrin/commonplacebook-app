// ABOUTME: Service that generates titles from note content using iOS Natural Language framework
// ABOUTME: Provides smart summarization with fallback to first-line extraction

import Foundation
import NaturalLanguage

/// Errors that can occur during title generation
enum TitleGeneratorError: Error, Equatable {
    case emptyContent
}

/// Service for generating titles from note content
@MainActor
class TitleGenerator {

    // MARK: - Constants

    private static let maxTitleLength = 100
    private static let fallbackMaxLength = 50
    private static let defaultFallbackTitle = "Note"

    // MARK: - Public Interface

    /// Generates a title from the given content
    /// - Parameter content: The content to generate a title from
    /// - Returns: A generated title (max 100 characters)
    func generateTitle(from content: String) -> String {
        // Clean the input
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle empty content
        guard !trimmedContent.isEmpty else {
            return Self.defaultFallbackTitle
        }

        // Try to generate title using NL framework
        if let summarizedTitle = extractKeyPhrase(from: trimmedContent) {
            return finalizeTitle(summarizedTitle)
        }

        // Fallback to first line
        return extractFirstLine(from: trimmedContent)
    }

    // MARK: - Private Helpers

    /// Extracts key phrase from content using Natural Language framework
    private func extractKeyPhrase(from content: String) -> String? {
        // Use NLTagger to identify important tokens
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = content

        // Extract important words (nouns, names, verbs) - use Set for O(1) duplicate checking
        var importantWords: [String] = []
        var seenWords = Set<String>()
        let maxWords = 10 // Aim for ~5-10 words

        tagger.enumerateTags(in: content.startIndex..<content.endIndex,
                            unit: .word,
                            scheme: .lexicalClass,
                            options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange in

            // Stop after collecting enough words
            guard importantWords.count < maxWords else { return false }

            let word = String(content[tokenRange])

            // Include nouns, proper nouns, verbs, and adjectives
            if let tag = tag {
                switch tag {
                case .noun, .verb, .adjective, .adverb:
                    if seenWords.insert(word).inserted {
                        importantWords.append(word)
                    }
                default:
                    break
                }
            }

            return true
        }

        // Reset counter for second pass - check for named entities (people, places, organizations)
        let remainingSlots = maxWords - importantWords.count
        guard remainingSlots > 0 else {
            // Already have enough words, return what we have
            return importantWords.joined(separator: " ")
        }

        var entitiesAdded = 0
        tagger.enumerateTags(in: content.startIndex..<content.endIndex,
                            unit: .word,
                            scheme: .nameType,
                            options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange in

            guard entitiesAdded < remainingSlots else { return false }

            if tag != nil {
                let word = String(content[tokenRange])
                // Avoid duplicates using Set
                if seenWords.insert(word).inserted {
                    importantWords.append(word)
                    entitiesAdded += 1
                }
            }

            return true
        }

        // If we found important words, join them (use maxWords for consistency)
        if !importantWords.isEmpty {
            return importantWords.prefix(maxWords).joined(separator: " ")
        }

        return nil
    }

    /// Extracts the first line from content with markdown cleanup
    private func extractFirstLine(from content: String) -> String {
        // Split into lines and get first non-empty line
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            // Strip markdown headers
            let cleanedLine = stripMarkdownHeaders(from: trimmedLine)

            // Truncate to max length
            let truncated = unicodeSafeTruncate(cleanedLine, maxLength: Self.fallbackMaxLength)

            return finalizeTitle(truncated)
        }

        // No non-empty lines found
        return Self.defaultFallbackTitle
    }

    /// Strips markdown header symbols from the beginning of text
    private func stripMarkdownHeaders(from text: String) -> String {
        // Remove leading # symbols and spaces (require space after # for valid markdown)
        let pattern = "^#+\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let result = regex.stringByReplacingMatches(in: text,
                                                    range: range,
                                                    withTemplate: "")

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Safely truncates a string to max length using shared extension
    private func unicodeSafeTruncate(_ string: String, maxLength: Int) -> String {
        return string.truncated(to: maxLength)
    }

    /// Finalizes the title by cleaning whitespace and enforcing max length
    private func finalizeTitle(_ title: String) -> String {
        // Clean up whitespace
        let components = title.components(separatedBy: .whitespacesAndNewlines)
        let cleaned = components
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Ensure max length
        let truncated = unicodeSafeTruncate(cleaned, maxLength: Self.maxTitleLength)

        // Final trim
        return truncated.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
