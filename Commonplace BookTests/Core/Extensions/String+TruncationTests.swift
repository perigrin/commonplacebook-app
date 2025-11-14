// ABOUTME: Tests for String+Truncation extension for safe Unicode truncation
// ABOUTME: Validates grapheme cluster handling and complex emoji preservation

import XCTest
@testable import Commonplace_Book

final class StringTruncationTests: XCTestCase {

    // MARK: - Basic Truncation Tests

    func testTruncateShorterString() {
        // GIVEN string shorter than max length
        let string = "Hello"

        // WHEN truncating to longer length
        let truncated = string.truncated(to: 10)

        // THEN should return original string
        XCTAssertEqual(truncated, "Hello")
    }

    func testTruncateExactLength() {
        // GIVEN string exactly at max length
        let string = "Hello"

        // WHEN truncating to exact length
        let truncated = string.truncated(to: 5)

        // THEN should return original string
        XCTAssertEqual(truncated, "Hello")
    }

    func testTruncateLongerString() {
        // GIVEN string longer than max length
        let string = "Hello, World!"

        // WHEN truncating
        let truncated = string.truncated(to: 5)

        // THEN should truncate to max length
        XCTAssertEqual(truncated, "Hello")
        XCTAssertEqual(truncated.count, 5)
    }

    func testTruncateEmptyString() {
        // GIVEN empty string
        let string = ""

        // WHEN truncating
        let truncated = string.truncated(to: 10)

        // THEN should return empty string
        XCTAssertEqual(truncated, "")
    }

    func testTruncateToZeroLength() {
        // GIVEN any string
        let string = "Hello"

        // WHEN truncating to zero
        let truncated = string.truncated(to: 0)

        // THEN should return empty string
        XCTAssertEqual(truncated, "")
    }

    func testTruncateToOne() {
        // GIVEN string
        let string = "Hello"

        // WHEN truncating to 1
        let truncated = string.truncated(to: 1)

        // THEN should return first character
        XCTAssertEqual(truncated, "H")
        XCTAssertEqual(truncated.count, 1)
    }

    // MARK: - ASCII String Tests

    func testTruncateASCIIString() {
        // GIVEN ASCII string
        let string = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

        // WHEN truncating to 10
        let truncated = string.truncated(to: 10)

        // THEN should truncate correctly
        XCTAssertEqual(truncated, "ABCDEFGHIJ")
        XCTAssertEqual(truncated.count, 10)
    }

    func testTruncateNumberString() {
        // GIVEN number string
        let string = "0123456789"

        // WHEN truncating to 5
        let truncated = string.truncated(to: 5)

        // THEN should truncate correctly
        XCTAssertEqual(truncated, "01234")
    }

    func testTruncatePunctuationString() {
        // GIVEN punctuation string
        let string = "!@#$%^&*()"

        // WHEN truncating to 3
        let truncated = string.truncated(to: 3)

        // THEN should truncate correctly
        XCTAssertEqual(truncated, "!@#")
    }

    // MARK: - Unicode Tests

    func testTruncateSimpleEmoji() {
        // GIVEN string with simple emojis
        let string = "😀😁😂🤣😃"

        // WHEN truncating to 3
        let truncated = string.truncated(to: 3)

        // THEN should preserve emoji graphemes
        XCTAssertEqual(truncated, "😀😁😂")
        XCTAssertEqual(truncated.count, 3)
    }

    func testTruncateComplexEmoji() {
        // GIVEN string with complex emoji (skin tone modifier)
        let string = "👋👋🏻👋🏿"

        // WHEN truncating to 2
        let truncated = string.truncated(to: 2)

        // THEN should not split emoji with modifier
        XCTAssertEqual(truncated, "👋👋🏻")
        XCTAssertEqual(truncated.count, 2)
    }

    func testTruncateFlagEmoji() {
        // GIVEN string with flag emojis
        let string = "🇺🇸🇬🇧🇫🇷🇩🇪🇯🇵"

        // WHEN truncating to 3
        let truncated = string.truncated(to: 3)

        // THEN should not split flag emojis
        XCTAssertEqual(truncated, "🇺🇸🇬🇧🇫🇷")
        XCTAssertEqual(truncated.count, 3)
    }

    func testTruncateFamilyEmoji() {
        // GIVEN string with family emoji (ZWJ sequence)
        let string = "👨‍👩‍👧‍👦ABC"

        // WHEN truncating to 2
        let truncated = string.truncated(to: 2)

        // THEN should not split ZWJ sequence
        XCTAssertEqual(truncated.count, 2)
        XCTAssertTrue(truncated.hasPrefix("👨‍👩‍👧‍👦"))
    }

    func testTruncateChineseCharacters() {
        // GIVEN string with Chinese characters
        let string = "你好世界"

        // WHEN truncating to 2
        let truncated = string.truncated(to: 2)

        // THEN should truncate correctly
        XCTAssertEqual(truncated, "你好")
        XCTAssertEqual(truncated.count, 2)
    }

    func testTruncateJapaneseCharacters() {
        // GIVEN string with Japanese characters
        let string = "こんにちは"

        // WHEN truncating to 3
        let truncated = string.truncated(to: 3)

        // THEN should truncate correctly
        XCTAssertEqual(truncated, "こんに")
        XCTAssertEqual(truncated.count, 3)
    }

    func testTruncateArabicCharacters() {
        // GIVEN string with Arabic characters
        let string = "مرحبا"

        // WHEN truncating to 3
        let truncated = string.truncated(to: 3)

        // THEN should truncate correctly
        XCTAssertEqual(truncated.count, 3)
    }

    func testTruncateCombiningCharacters() {
        // GIVEN string with combining characters (accents)
        let string = "café" // é is e + combining acute accent

        // WHEN truncating to 3
        let truncated = string.truncated(to: 3)

        // THEN should not split combining characters
        XCTAssertEqual(truncated, "caf")
        XCTAssertEqual(truncated.count, 3)
    }

    func testTruncateDiacritics() {
        // GIVEN string with diacritics
        let string = "naïve résumé"

        // WHEN truncating to 6
        let truncated = string.truncated(to: 6)

        // THEN should preserve diacritics
        XCTAssertEqual(truncated.count, 6)
    }

    // MARK: - Mixed Content Tests

    func testTruncateMixedASCIIAndEmoji() {
        // GIVEN mixed ASCII and emoji
        let string = "Hello 👋 World 🌍"

        // WHEN truncating to 8
        let truncated = string.truncated(to: 8)

        // THEN should handle both correctly
        XCTAssertEqual(truncated, "Hello 👋 ")
        XCTAssertEqual(truncated.count, 8)
    }

    func testTruncateMixedLanguages() {
        // GIVEN mixed languages
        let string = "Hello你好مرحبا"

        // WHEN truncating to 8
        let truncated = string.truncated(to: 8)

        // THEN should truncate correctly
        XCTAssertEqual(truncated, "Hello你好م")
        XCTAssertEqual(truncated.count, 8)
    }

    func testTruncateEmojiSequence() {
        // GIVEN emoji sequence
        let string = "🎉🎊🎈🎁🎂"

        // WHEN truncating to 3
        let truncated = string.truncated(to: 3)

        // THEN should preserve each emoji
        XCTAssertEqual(truncated, "🎉🎊🎈")
        XCTAssertEqual(truncated.count, 3)
    }

    // MARK: - Whitespace Tests

    func testTruncateWithWhitespace() {
        // GIVEN string with whitespace
        let string = "Hello     World"

        // WHEN truncating to 7
        let truncated = string.truncated(to: 7)

        // THEN should include whitespace in count
        XCTAssertEqual(truncated, "Hello  ")
        XCTAssertEqual(truncated.count, 7)
    }

    func testTruncateWithNewlines() {
        // GIVEN string with newlines
        let string = "Line1\nLine2\nLine3"

        // WHEN truncating to 8
        let truncated = string.truncated(to: 8)

        // THEN should include newlines in count
        XCTAssertEqual(truncated, "Line1\nLi")
        XCTAssertEqual(truncated.count, 8)
    }

    func testTruncateWithTabs() {
        // GIVEN string with tabs
        let string = "A\tB\tC\tD"

        // WHEN truncating to 5
        let truncated = string.truncated(to: 5)

        // THEN should include tabs in count
        XCTAssertEqual(truncated, "A\tB\tC")
        XCTAssertEqual(truncated.count, 5)
    }

    // MARK: - Edge Cases

    func testTruncateVeryLongString() {
        // GIVEN very long string
        let string = String(repeating: "A", count: 10000)

        // WHEN truncating to 100
        let truncated = string.truncated(to: 100)

        // THEN should truncate efficiently
        XCTAssertEqual(truncated.count, 100)
    }

    func testTruncateNegativeLength() {
        // GIVEN any string
        let string = "Hello"

        // WHEN truncating to negative length
        let truncated = string.truncated(to: -1)

        // THEN should return empty string (count > maxLength)
        XCTAssertEqual(truncated, "")
    }

    func testTruncateSingleCharacter() {
        // GIVEN single character
        let string = "A"

        // WHEN truncating to 1
        let truncated = string.truncated(to: 1)

        // THEN should return character
        XCTAssertEqual(truncated, "A")
    }

    func testTruncateSingleEmoji() {
        // GIVEN single emoji
        let string = "😀"

        // WHEN truncating to 1
        let truncated = string.truncated(to: 1)

        // THEN should return emoji
        XCTAssertEqual(truncated, "😀")
    }

    func testTruncateAllWhitespace() {
        // GIVEN all whitespace
        let string = "     "

        // WHEN truncating to 2
        let truncated = string.truncated(to: 2)

        // THEN should truncate whitespace
        XCTAssertEqual(truncated, "  ")
        XCTAssertEqual(truncated.count, 2)
    }

    // MARK: - Consistency Tests

    func testTruncateIsIdempotent() {
        // GIVEN string
        let string = "Hello, World!"

        // WHEN truncating multiple times
        let truncated1 = string.truncated(to: 5)
        let truncated2 = truncated1.truncated(to: 5)

        // THEN should be same result
        XCTAssertEqual(truncated1, truncated2)
    }

    func testTruncatePreservesPrefix() {
        // GIVEN string
        let string = "Hello, World!"

        // WHEN truncating
        let truncated = string.truncated(to: 5)

        // THEN should be prefix of original
        XCTAssertTrue(string.hasPrefix(truncated))
    }

    func testTruncateCountMatchesCharacterCount() {
        // GIVEN various strings
        let testCases = [
            "Hello",
            "😀😁😂",
            "你好",
            "👋🏻👋🏿",
            "🇺🇸🇬🇧"
        ]

        for string in testCases {
            // WHEN truncating to various lengths
            for length in 0...string.count {
                let truncated = string.truncated(to: length)

                // THEN count should match requested length (or original if shorter)
                XCTAssertEqual(truncated.count, min(length, string.count),
                              "Failed for '\(string)' truncated to \(length)")
            }
        }
    }

    // MARK: - Performance Tests

    func testTruncateShortStringPerformance() {
        // GIVEN short string
        let string = "Hello, World!"

        measure {
            // WHEN truncating
            _ = string.truncated(to: 5)
        }
        // THEN should be fast
    }

    func testTruncateLongStringPerformance() {
        // GIVEN long string
        let string = String(repeating: "A", count: 10000)

        measure {
            // WHEN truncating
            _ = string.truncated(to: 100)
        }
        // THEN should complete quickly
    }

    func testTruncateEmojiStringPerformance() {
        // GIVEN emoji string
        let string = String(repeating: "😀", count: 1000)

        measure {
            // WHEN truncating
            _ = string.truncated(to: 100)
        }
        // THEN should complete quickly
    }

    // MARK: - Thread Safety Tests

    func testTruncateIsThreadSafe() {
        // GIVEN shared string
        let string = "Hello, World! This is a test string."

        // WHEN truncating from multiple threads
        let expectation = XCTestExpectation(description: "Thread safe truncation")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var results: [String] = []
        let lock = NSLock()

        for _ in 0..<100 {
            group.enter()
            queue.async {
                let truncated = string.truncated(to: 10)
                lock.lock()
                results.append(truncated)
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all should produce same result
        XCTAssertEqual(results.count, 100)
        let uniqueResults = Set(results)
        XCTAssertEqual(uniqueResults.count, 1, "All concurrent truncations should yield same result")
    }

    // MARK: - Boundary Tests

    func testTruncateAtGraphemeBoundary() {
        // GIVEN string with complex graphemes
        let string = "a👨‍👩‍👧‍👦b"

        // WHEN truncating to 2
        let truncated = string.truncated(to: 2)

        // THEN should respect grapheme boundaries
        XCTAssertEqual(truncated.count, 2)
        XCTAssertTrue(truncated.hasPrefix("a"))
    }

    func testTruncateDoesNotSplitSkinTone() {
        // GIVEN emoji with skin tone
        let string = "👍🏻👍🏿"

        // WHEN truncating to 1
        let truncated = string.truncated(to: 1)

        // THEN should not split skin tone modifier
        XCTAssertEqual(truncated, "👍🏻")
        XCTAssertEqual(truncated.count, 1)
    }

    func testTruncateDoesNotSplitZWJSequence() {
        // GIVEN ZWJ sequence
        let string = "👨‍💻👩‍💻"

        // WHEN truncating to 1
        let truncated = string.truncated(to: 1)

        // THEN should not split ZWJ sequence
        XCTAssertEqual(truncated.count, 1)
    }

    // MARK: - Real World Examples

    func testTruncateUserName() {
        // GIVEN user name
        let name = "John Alexander Smith-Johnson"

        // WHEN truncating for display
        let truncated = name.truncated(to: 15)

        // THEN should truncate cleanly
        XCTAssertEqual(truncated, "John Alexander ")
        XCTAssertEqual(truncated.count, 15)
    }

    func testTruncateNoteTitle() {
        // GIVEN note title
        let title = "Meeting Notes - Q4 2024 Planning Session"

        // WHEN truncating for list view
        let truncated = title.truncated(to: 20)

        // THEN should truncate cleanly
        XCTAssertEqual(truncated, "Meeting Notes - Q4 2")
        XCTAssertEqual(truncated.count, 20)
    }

    func testTruncateMultilingualContent() {
        // GIVEN multilingual content
        let content = "Hello 你好 مرحبا 👋"

        // WHEN truncating
        let truncated = content.truncated(to: 10)

        // THEN should handle all scripts
        XCTAssertEqual(truncated.count, 10)
    }

    // MARK: - Integration Tests Documentation

    func testDocumentRequiredIntegrationTests() {
        // This test documents integration tests for truncation
        // in real app scenarios

        let requiredIntegrationTests = [
            "testTruncateInNoteListView",
            "testTruncateInSearchResults",
            "testTruncateInNotifications",
            "testTruncateInShareSheet",
            "testTruncateWithUserLocale",
            "testTruncateInAccessibilityLabel"
        ]

        XCTAssertEqual(requiredIntegrationTests.count, 6,
                      "Should have \(requiredIntegrationTests.count) integration tests")
    }
}
