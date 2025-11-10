// ABOUTME: Tests for AbstractGenerator that creates note previews from content
// ABOUTME: Validates markdown stripping, smart truncation, word boundaries, and edge cases

import XCTest
import NaturalLanguage
@testable import Template_App

final class AbstractGeneratorTests: XCTestCase {
    var generator: AbstractGenerator!

    override func setUpWithError() throws {
        generator = AbstractGenerator()
    }

    override func tearDownWithError() throws {
        generator = nil
    }

    // MARK: - Basic Functionality Tests

    func testGenerateAbstractFromShortContent() throws {
        // GIVEN short content (under max length)
        let content = "This is a short note."

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content, maxLength: 100)

        // THEN returns content as-is
        XCTAssertEqual(abstract, "This is a short note.")
    }

    func testGenerateAbstractFromLongContent() throws {
        // GIVEN long content (over max length)
        let content = "This is a very long note that contains a lot of text. It has multiple sentences and should be truncated to fit within the maximum length limit. This part should not appear in the abstract."

        // WHEN generating abstract with 100 char limit
        let abstract = generator.generateAbstract(from: content, maxLength: 100)

        // THEN truncates with ellipsis
        XCTAssertTrue(abstract.hasSuffix("..."), "Should end with ellipsis")
        XCTAssertLessThanOrEqual(abstract.count, 103, "Should be within max length + ellipsis")
    }

    func testDefaultMaxLengthIs100() throws {
        // GIVEN generator and long content
        let content = String(repeating: "a", count: 200)

        // WHEN generating abstract without specifying max length
        let abstract = generator.generateAbstract(from: content)

        // THEN uses default of 100
        XCTAssertLessThanOrEqual(abstract.count, 103, "Should use default max length of 100")
    }

    // MARK: - Markdown Stripping Tests

    func testStripMarkdownHeaders() throws {
        // GIVEN content with markdown headers
        let content = "# Header 1\n## Header 2\n### Header 3\nRegular text"

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN headers stripped
        XCTAssertFalse(abstract.contains("#"), "Should not contain # characters")
        XCTAssertTrue(abstract.contains("Header 1"), "Should contain header text")
        XCTAssertTrue(abstract.contains("Regular text"), "Should contain regular text")
    }

    func testStripMarkdownLinks() throws {
        // GIVEN content with markdown links
        let content = "Check out [this link](https://example.com) for more info."

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN links stripped to text only
        XCTAssertTrue(abstract.contains("this link"), "Should contain link text")
        XCTAssertFalse(abstract.contains("["), "Should not contain brackets")
        XCTAssertFalse(abstract.contains("]"), "Should not contain brackets")
        XCTAssertFalse(abstract.contains("(https://"), "Should not contain URL")
    }

    func testStripMarkdownBold() throws {
        // GIVEN content with bold text
        let content = "This is **bold text** and __also bold__."

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN asterisks and underscores stripped
        XCTAssertTrue(abstract.contains("bold text"), "Should contain bold text")
        XCTAssertFalse(abstract.contains("**"), "Should not contain asterisks")
        XCTAssertFalse(abstract.contains("__"), "Should not contain underscores")
    }

    func testStripMarkdownItalic() throws {
        // GIVEN content with italic text
        let content = "This is *italic* and _also italic_."

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN asterisks and underscores stripped
        XCTAssertTrue(abstract.contains("italic"), "Should contain italic text")
        XCTAssertFalse(abstract.contains("*"), "Should not contain asterisks")
        XCTAssertFalse(abstract.contains("_"), "Should not contain underscores")
    }

    func testStripMarkdownCode() throws {
        // GIVEN content with code blocks and inline code
        let content = "Use `code` inline and ```\ncode block\n``` too."

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN backticks stripped
        XCTAssertTrue(abstract.contains("code"), "Should contain code text")
        XCTAssertFalse(abstract.contains("`"), "Should not contain backticks")
    }

    func testStripMarkdownLists() throws {
        // GIVEN content with lists
        let content = "- Item 1\n- Item 2\n* Item 3\n1. Numbered"

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN list markers stripped
        XCTAssertTrue(abstract.contains("Item"), "Should contain item text")
        XCTAssertFalse(abstract.hasPrefix("-"), "Should not start with dash")
        XCTAssertFalse(abstract.hasPrefix("*"), "Should not start with asterisk")
    }

    // MARK: - Smart Truncation Tests

    func testTruncateAtWordBoundary() throws {
        // GIVEN content that would truncate mid-word
        let content = "This is a sentence with verylongword at position 95 exactly."

        // WHEN generating abstract with 100 char limit
        let abstract = generator.generateAbstract(from: content, maxLength: 100)

        // THEN truncates at previous word boundary
        XCTAssertFalse(abstract.contains("verylongword"), "Should not include partial word")
        XCTAssertTrue(abstract.hasSuffix("..."), "Should end with ellipsis")
        XCTAssertFalse(abstract.dropLast(3).hasSuffix(" "), "Should not have trailing space before ellipsis")
    }

    func testAddEllipsisWhenTruncated() throws {
        // GIVEN long content
        let content = String(repeating: "word ", count: 50)

        // WHEN generating abstract with short max length
        let abstract = generator.generateAbstract(from: content, maxLength: 50)

        // THEN ends with ellipsis
        XCTAssertTrue(abstract.hasSuffix("..."), "Truncated content should end with ...")
    }

    func testNoEllipsisWhenNotTruncated() throws {
        // GIVEN short content
        let content = "Short text"

        // WHEN generating abstract with long max length
        let abstract = generator.generateAbstract(from: content, maxLength: 100)

        // THEN no ellipsis
        XCTAssertFalse(abstract.hasSuffix("..."), "Short content should not have ellipsis")
    }

    // MARK: - Edge Case Tests

    func testHandleEmptyContent() throws {
        // GIVEN empty content
        let content = ""

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN returns empty string
        XCTAssertEqual(abstract, "", "Empty content should return empty abstract")
    }

    func testHandleWhitespaceOnlyContent() throws {
        // GIVEN whitespace-only content
        let content = "   \n\t  \n   "

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN returns empty string
        XCTAssertEqual(abstract, "", "Whitespace-only content should return empty abstract")
    }

    func testHandleContentWithOnlyMarkdown() throws {
        // GIVEN content with only markdown syntax
        let content = "## ### **__ ```code``` [link](url)"

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN returns empty or minimal text
        XCTAssertLessThan(abstract.count, 20, "Should have minimal text after stripping")
    }

    func testHandleSingleLongWord() throws {
        // GIVEN single word longer than max length
        let content = String(repeating: "a", count: 150)

        // WHEN generating abstract with 100 char limit
        let abstract = generator.generateAbstract(from: content, maxLength: 100)

        // THEN truncates with ellipsis
        XCTAssertTrue(abstract.hasSuffix("..."), "Should truncate long word")
        XCTAssertLessThanOrEqual(abstract.count, 103)
    }

    func testHandleMultipleNewlines() throws {
        // GIVEN content with multiple newlines
        let content = "Line 1\n\n\nLine 2\n\n\nLine 3"

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content)

        // THEN normalizes whitespace
        XCTAssertFalse(abstract.contains("\n\n\n"), "Should normalize multiple newlines")
        XCTAssertTrue(abstract.contains("Line 1"), "Should contain content")
    }

    // MARK: - Integration Tests

    func testComplexMarkdownDocument() throws {
        // GIVEN complex markdown document
        let content = """
        # My Note

        This is a **bold** statement with *italic* text.

        - List item 1
        - List item 2

        Check [this link](https://example.com) for more.

        ## Section 2

        Some `inline code` here.
        """

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content, maxLength: 100)

        // THEN all markdown stripped
        XCTAssertFalse(abstract.contains("#"), "Should not contain headers")
        XCTAssertFalse(abstract.contains("**"), "Should not contain bold markers")
        XCTAssertFalse(abstract.contains("*"), "Should not contain italic markers")
        XCTAssertFalse(abstract.contains("-"), "Should not contain list markers")
        XCTAssertFalse(abstract.contains("["), "Should not contain link syntax")
        XCTAssertFalse(abstract.contains("`"), "Should not contain code markers")
        XCTAssertTrue(abstract.contains("bold"), "Should contain text")
        XCTAssertTrue(abstract.contains("italic"), "Should contain text")
    }

    func testRealWorldNoteContent() throws {
        // GIVEN realistic note content
        let content = """
        Met with **John** today to discuss the Q4 roadmap.

        Key takeaways:
        - Focus on [mobile experience](https://docs.example.com/mobile)
        - Ship by __December 15th__
        - Need 3 engineers

        Next steps: schedule follow-up for `code review`.
        """

        // WHEN generating abstract
        let abstract = generator.generateAbstract(from: content, maxLength: 100)

        // THEN readable preview without markdown
        XCTAssertTrue(abstract.contains("Met with John"), "Should have readable start")
        XCTAssertLessThanOrEqual(abstract.count, 103)
        XCTAssertFalse(abstract.contains("**"), "Should strip markdown")
    }

    // MARK: - Performance Tests

    func testPerformanceWithLargeDocument() throws {
        // GIVEN very large document
        let content = String(repeating: "This is a sentence with many words. ", count: 1000)

        // WHEN measuring performance
        measure {
            _ = generator.generateAbstract(from: content, maxLength: 100)
        }

        // Performance should be reasonable (< 0.1s)
    }
}
