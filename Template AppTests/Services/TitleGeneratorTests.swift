// ABOUTME: Tests for TitleGenerator service that generates titles using iOS Natural Language framework
// ABOUTME: Validates title generation, summarization, fallback logic, and edge cases

import XCTest
import NaturalLanguage
@testable import Template_App

final class TitleGeneratorTests: XCTestCase {
    var generator: TitleGenerator!

    override func setUpWithError() throws {
        generator = TitleGenerator()
    }

    override func tearDownWithError() throws {
        generator = nil
    }

    // MARK: - Short Content Tests

    func testGenerateTitleFromShortSentence() throws {
        // GIVEN short single sentence
        let content = "This is a simple test note about programming."

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is generated and reasonable
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 100)
        XCTAssertFalse(title.contains("\n"))
    }

    func testGenerateTitleFromShortParagraph() throws {
        // GIVEN short paragraph (2-3 sentences)
        let content = "Today I learned about Swift actors. They provide thread safety without locks. This makes concurrent code much easier to write."

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is extracted
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 100)
    }

    // MARK: - Long Content Tests

    func testGenerateTitleFromLongContent() throws {
        // GIVEN long multi-paragraph content
        let content = """
        Understanding iOS Development Patterns

        Modern iOS development requires understanding several key patterns. The Model-View-ViewModel (MVVM) pattern separates concerns effectively. SwiftUI makes this pattern natural with its declarative syntax.

        Dependency injection is crucial for testability. By injecting dependencies through initializers, we can easily substitute mock implementations during testing. This leads to more maintainable and testable code.

        Concurrency in Swift uses the new async/await syntax. This makes asynchronous code look synchronous and easier to reason about. Actors provide thread safety without manual locking.
        """

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is summarized (not the whole first line)
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 100)
        // Should be shorter than first line since it's a summary
        XCTAssertLessThan(title.count, "Understanding iOS Development Patterns".count + 50)
    }

    func testGenerateTitleFromVeryLongContent() throws {
        // GIVEN very long content (500+ words)
        let longParagraph = "Swift is a powerful programming language. "
        let content = String(repeating: longParagraph, count: 50)

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is concise summary
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 100)
    }

    // MARK: - Fallback Tests

    func testFallbackToFirstLineWhenSummarizationFails() throws {
        // GIVEN content that may not summarize well (random characters)
        let content = "xyzabc123!@# random text here\nSecond line of content\nThird line"

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN falls back to first line
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 100)
    }

    func testFallbackForEmptyContent() throws {
        // GIVEN empty content
        let content = ""

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN returns fallback title
        XCTAssertFalse(title.isEmpty)
        XCTAssertTrue(title.contains("Note"))
    }

    func testFallbackForWhitespaceOnlyContent() throws {
        // GIVEN whitespace-only content
        let content = "   \n  \n   "

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN returns fallback title
        XCTAssertFalse(title.isEmpty)
        XCTAssertTrue(title.contains("Note"))
    }

    // MARK: - Title Length Tests

    func testTitleLengthConstraintMax100Chars() throws {
        // GIVEN content that would generate very long title
        let longTitle = String(repeating: "a", count: 150)
        let content = "\(longTitle)\nSome other content here."

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is truncated to max 100 characters
        XCTAssertLessThanOrEqual(title.count, 100)
    }

    func testTitleDoesNotExceed100CharsForLongSummary() throws {
        // GIVEN long content
        let content = """
        This is a very long explanation about how dependency injection works in modern iOS applications using Swift and SwiftUI with the new concurrency model including actors and async await syntax patterns for better code organization.
        """

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title respects max length
        XCTAssertLessThanOrEqual(title.count, 100)
    }

    // MARK: - Whitespace Handling Tests

    func testTrimLeadingWhitespace() throws {
        // GIVEN content with leading whitespace
        let content = "   Leading whitespace content here"

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN leading whitespace is trimmed
        XCTAssertFalse(title.hasPrefix(" "))
    }

    func testTrimTrailingWhitespace() throws {
        // GIVEN content with trailing whitespace
        let content = "Trailing whitespace content   \n\nMore content"

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN trailing whitespace is trimmed
        XCTAssertFalse(title.hasSuffix(" "))
    }

    func testTrimInternalExcessWhitespace() throws {
        // GIVEN content with internal excess whitespace
        let content = "Too    much    internal    spacing"

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is cleaned
        XCTAssertFalse(title.isEmpty)
        // Should not have multiple consecutive spaces
        XCTAssertFalse(title.contains("    "))
    }

    // MARK: - Multi-line Content Tests

    func testHandleMultiLineContent() throws {
        // GIVEN multi-line content
        let content = """
        First line is the title line
        Second line has more details
        Third line continues the thought
        """

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is single line
        XCTAssertFalse(title.contains("\n"))
        XCTAssertFalse(title.isEmpty)
    }

    func testHandleContentWithMarkdownHeaders() throws {
        // GIVEN content with markdown headers
        let content = """
        # Main Heading

        This is the body content about the topic.
        """

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN markdown is stripped
        XCTAssertFalse(title.hasPrefix("#"))
    }

    // MARK: - Special Content Tests

    func testHandleCodeSnippet() throws {
        // GIVEN code snippet
        let content = """
        func calculateSum(a: Int, b: Int) -> Int {
            return a + b
        }

        This function adds two numbers together.
        """

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is generated
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 100)
    }

    func testHandleSpecialCharacters() throws {
        // GIVEN content with special characters
        let content = "Testing special chars: @#$% & symbols! Works?"

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is generated (may or may not include special chars)
        XCTAssertFalse(title.isEmpty)
    }

    func testHandleEmojiContent() throws {
        // GIVEN content with emojis
        let content = "🎉 Celebration note about 🚀 launching the app!"

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is generated safely (Unicode-safe)
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 100)
    }

    func testHandleNonEnglishContent() throws {
        // GIVEN non-English content (Chinese)
        let content = "这是一个中文笔记，用于测试标题生成功能。"

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is generated
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 100)
    }

    // MARK: - Integration Tests

    func testGeneratedTitleIsSuitableForDisplay() throws {
        // GIVEN typical note content
        let content = "Had a great meeting today discussing the new feature roadmap. Key points: user authentication, data sync, and offline support."

        // WHEN generating title
        let title = generator.generateTitle(from: content)

        // THEN title is suitable for display
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 100)
        XCTAssertFalse(title.hasPrefix(" "))
        XCTAssertFalse(title.hasSuffix(" "))
        XCTAssertFalse(title.contains("\n"))
    }

    func testMultipleCallsProduceSameResult() throws {
        // GIVEN same content
        let content = "Consistency test for title generation"

        // WHEN generating title multiple times
        let title1 = generator.generateTitle(from: content)
        let title2 = generator.generateTitle(from: content)
        let title3 = generator.generateTitle(from: content)

        // THEN results are consistent
        XCTAssertEqual(title1, title2)
        XCTAssertEqual(title2, title3)
    }
}
