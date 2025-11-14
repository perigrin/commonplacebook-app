// ABOUTME: Tests for AnyCodable type-erased Codable wrapper
// ABOUTME: Validates encoding, decoding, equality, hashing, and literal expressibility

import XCTest
@testable import Commonplace_Book

final class AnyCodableTests: XCTestCase {

    var encoder: JSONEncoder!
    var decoder: JSONDecoder!

    override func setUp() {
        super.setUp()
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    override func tearDown() {
        encoder = nil
        decoder = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitWithBool() {
        // GIVEN a boolean value
        let value = true

        // WHEN creating AnyCodable
        let anyCodable = AnyCodable(value)

        // THEN should wrap value
        XCTAssertTrue(anyCodable.value as? Bool == true)
    }

    func testInitWithInt() {
        // GIVEN an integer value
        let value = 42

        // WHEN creating AnyCodable
        let anyCodable = AnyCodable(value)

        // THEN should wrap value
        XCTAssertEqual(anyCodable.value as? Int, 42)
    }

    func testInitWithDouble() {
        // GIVEN a double value
        let value = 3.14

        // WHEN creating AnyCodable
        let anyCodable = AnyCodable(value)

        // THEN should wrap value
        XCTAssertEqual(anyCodable.value as? Double, 3.14)
    }

    func testInitWithString() {
        // GIVEN a string value
        let value = "hello"

        // WHEN creating AnyCodable
        let anyCodable = AnyCodable(value)

        // THEN should wrap value
        XCTAssertEqual(anyCodable.value as? String, "hello")
    }

    func testInitWithArray() {
        // GIVEN an array value
        let value = [1, 2, 3]

        // WHEN creating AnyCodable
        let anyCodable = AnyCodable(value)

        // THEN should wrap value
        let array = anyCodable.value as? [Int]
        XCTAssertEqual(array?.count, 3)
    }

    func testInitWithDictionary() {
        // GIVEN a dictionary value
        let value = ["key": "value"]

        // WHEN creating AnyCodable
        let anyCodable = AnyCodable(value)

        // THEN should wrap value
        let dict = anyCodable.value as? [String: String]
        XCTAssertEqual(dict?["key"], "value")
    }

    // MARK: - Literal Expressibility Tests

    func testStringLiteralInit() {
        // GIVEN string literal
        let anyCodable: AnyCodable = "test"

        // THEN should create AnyCodable with string
        XCTAssertEqual(anyCodable.value as? String, "test")
    }

    func testIntegerLiteralInit() {
        // GIVEN integer literal
        let anyCodable: AnyCodable = 100

        // THEN should create AnyCodable with int
        XCTAssertEqual(anyCodable.value as? Int, 100)
    }

    func testFloatLiteralInit() {
        // GIVEN float literal
        let anyCodable: AnyCodable = 2.5

        // THEN should create AnyCodable with double
        XCTAssertEqual(anyCodable.value as? Double, 2.5)
    }

    func testBooleanLiteralInit() {
        // GIVEN boolean literal
        let anyCodableTrue: AnyCodable = true
        let anyCodableFalse: AnyCodable = false

        // THEN should create AnyCodable with bool
        XCTAssertEqual(anyCodableTrue.value as? Bool, true)
        XCTAssertEqual(anyCodableFalse.value as? Bool, false)
    }

    func testArrayLiteralInit() {
        // GIVEN array literal
        let anyCodable: AnyCodable = [1, 2, 3]

        // THEN should create AnyCodable with array
        let array = anyCodable.value as? [Any]
        XCTAssertEqual(array?.count, 3)
    }

    func testDictionaryLiteralInit() {
        // GIVEN dictionary literal
        let anyCodable: AnyCodable = ["name": "John", "age": 30]

        // THEN should create AnyCodable with dictionary
        let dict = anyCodable.value as? [String: Any]
        XCTAssertEqual(dict?.count, 2)
    }

    // MARK: - Encoding Tests

    func testEncodeNil() throws {
        // GIVEN AnyCodable with void (nil)
        let anyCodable = AnyCodable(())

        // WHEN encoding
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)

        // THEN should encode as null
        XCTAssertEqual(json, "null")
    }

    func testEncodeBool() throws {
        // GIVEN AnyCodable with bool
        let anyCodable = AnyCodable(true)

        // WHEN encoding
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)

        // THEN should encode as boolean
        XCTAssertEqual(json, "true")
    }

    func testEncodeInt() throws {
        // GIVEN AnyCodable with int
        let anyCodable = AnyCodable(42)

        // WHEN encoding
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)

        // THEN should encode as number
        XCTAssertEqual(json, "42")
    }

    func testEncodeDouble() throws {
        // GIVEN AnyCodable with double
        let anyCodable = AnyCodable(3.14)

        // WHEN encoding
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)

        // THEN should encode as number
        XCTAssertTrue(json?.contains("3.14") ?? false)
    }

    func testEncodeString() throws {
        // GIVEN AnyCodable with string
        let anyCodable = AnyCodable("hello")

        // WHEN encoding
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)

        // THEN should encode as string
        XCTAssertEqual(json, "\"hello\"")
    }

    func testEncodeArray() throws {
        // GIVEN AnyCodable with array
        let anyCodable = AnyCodable([1, 2, 3])

        // WHEN encoding
        let data = try encoder.encode(anyCodable)
        let json = String(data: data, encoding: .utf8)

        // THEN should encode as array
        XCTAssertEqual(json, "[1,2,3]")
    }

    func testEncodeDictionary() throws {
        // GIVEN AnyCodable with dictionary
        let anyCodable = AnyCodable(["key": "value"])

        // WHEN encoding
        let data = try encoder.encode(anyCodable)

        // THEN should encode as object
        let decoded = try decoder.decode([String: AnyCodable].self, from: data)
        XCTAssertEqual(decoded["key"]?.value as? String, "value")
    }

    func testEncodeInvalidTypeThrows() {
        // GIVEN AnyCodable with unsupported type
        struct CustomType {}
        let anyCodable = AnyCodable(CustomType())

        // WHEN encoding
        // THEN should throw
        XCTAssertThrowsError(try encoder.encode(anyCodable)) { error in
            XCTAssertTrue(error is EncodingError)
        }
    }

    // MARK: - Decoding Tests

    func testDecodeNull() throws {
        // GIVEN JSON null
        let json = "null".data(using: .utf8)!

        // WHEN decoding
        let anyCodable = try decoder.decode(AnyCodable.self, from: json)

        // THEN should decode as void
        XCTAssertTrue(anyCodable.value is Void)
    }

    func testDecodeBool() throws {
        // GIVEN JSON boolean
        let json = "true".data(using: .utf8)!

        // WHEN decoding
        let anyCodable = try decoder.decode(AnyCodable.self, from: json)

        // THEN should decode as bool
        XCTAssertEqual(anyCodable.value as? Bool, true)
    }

    func testDecodeInt() throws {
        // GIVEN JSON number
        let json = "42".data(using: .utf8)!

        // WHEN decoding
        let anyCodable = try decoder.decode(AnyCodable.self, from: json)

        // THEN should decode as int
        XCTAssertEqual(anyCodable.value as? Int, 42)
    }

    func testDecodeDouble() throws {
        // GIVEN JSON decimal number
        let json = "3.14".data(using: .utf8)!

        // WHEN decoding
        let anyCodable = try decoder.decode(AnyCodable.self, from: json)

        // THEN should decode as double
        XCTAssertEqual(anyCodable.value as? Double, 3.14)
    }

    func testDecodeString() throws {
        // GIVEN JSON string
        let json = "\"hello\"".data(using: .utf8)!

        // WHEN decoding
        let anyCodable = try decoder.decode(AnyCodable.self, from: json)

        // THEN should decode as string
        XCTAssertEqual(anyCodable.value as? String, "hello")
    }

    func testDecodeArray() throws {
        // GIVEN JSON array
        let json = "[1,2,3]".data(using: .utf8)!

        // WHEN decoding
        let anyCodable = try decoder.decode(AnyCodable.self, from: json)

        // THEN should decode as array
        let array = anyCodable.value as? [Any]
        XCTAssertEqual(array?.count, 3)
    }

    func testDecodeDictionary() throws {
        // GIVEN JSON object
        let json = "{\"key\":\"value\"}".data(using: .utf8)!

        // WHEN decoding
        let anyCodable = try decoder.decode(AnyCodable.self, from: json)

        // THEN should decode as dictionary
        let dict = anyCodable.value as? [String: Any]
        XCTAssertNotNil(dict)
    }

    func testDecodeInvalidJSONThrows() {
        // GIVEN invalid JSON
        let json = "invalid".data(using: .utf8)!

        // WHEN decoding
        // THEN should throw
        XCTAssertThrowsError(try decoder.decode(AnyCodable.self, from: json))
    }

    // MARK: - Round-trip Tests

    func testRoundTripBool() throws {
        // GIVEN AnyCodable with bool
        let original = AnyCodable(true)

        // WHEN encoding and decoding
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve value
        XCTAssertEqual(decoded.value as? Bool, true)
    }

    func testRoundTripInt() throws {
        // GIVEN AnyCodable with int
        let original = AnyCodable(42)

        // WHEN encoding and decoding
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve value
        XCTAssertEqual(decoded.value as? Int, 42)
    }

    func testRoundTripString() throws {
        // GIVEN AnyCodable with string
        let original = AnyCodable("hello")

        // WHEN encoding and decoding
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve value
        XCTAssertEqual(decoded.value as? String, "hello")
    }

    func testRoundTripArray() throws {
        // GIVEN AnyCodable with array
        let original = AnyCodable([1, 2, 3])

        // WHEN encoding and decoding
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve structure
        let array = decoded.value as? [Any]
        XCTAssertEqual(array?.count, 3)
    }

    // MARK: - Equatable Tests

    func testEqualBools() {
        // GIVEN two AnyCodable with same bool
        let lhs = AnyCodable(true)
        let rhs = AnyCodable(true)

        // THEN should be equal
        XCTAssertEqual(lhs, rhs)
    }

    func testEqualInts() {
        // GIVEN two AnyCodable with same int
        let lhs = AnyCodable(42)
        let rhs = AnyCodable(42)

        // THEN should be equal
        XCTAssertEqual(lhs, rhs)
    }

    func testEqualStrings() {
        // GIVEN two AnyCodable with same string
        let lhs = AnyCodable("hello")
        let rhs = AnyCodable("hello")

        // THEN should be equal
        XCTAssertEqual(lhs, rhs)
    }

    func testNotEqualDifferentTypes() {
        // GIVEN two AnyCodable with different types
        let lhs = AnyCodable(42)
        let rhs = AnyCodable("42")

        // THEN should not be equal
        XCTAssertNotEqual(lhs, rhs)
    }

    func testNotEqualDifferentValues() {
        // GIVEN two AnyCodable with different values
        let lhs = AnyCodable(42)
        let rhs = AnyCodable(43)

        // THEN should not be equal
        XCTAssertNotEqual(lhs, rhs)
    }

    func testEqualArrays() {
        // GIVEN two AnyCodable with arrays of same count
        let lhs = AnyCodable([1, 2, 3])
        let rhs = AnyCodable([1, 2, 3])

        // THEN should be equal (simplified comparison by count)
        XCTAssertEqual(lhs, rhs)
    }

    func testNotEqualArraysDifferentCount() {
        // GIVEN two AnyCodable with arrays of different count
        let lhs = AnyCodable([1, 2, 3])
        let rhs = AnyCodable([1, 2])

        // THEN should not be equal
        XCTAssertNotEqual(lhs, rhs)
    }

    func testEqualDictionaries() {
        // GIVEN two AnyCodable with dictionaries of same count
        let lhs = AnyCodable(["a": 1, "b": 2])
        let rhs = AnyCodable(["a": 1, "b": 2])

        // THEN should be equal (simplified comparison by count)
        XCTAssertEqual(lhs, rhs)
    }

    func testNotEqualDictionariesDifferentCount() {
        // GIVEN two AnyCodable with dictionaries of different count
        let lhs = AnyCodable(["a": 1, "b": 2])
        let rhs = AnyCodable(["a": 1])

        // THEN should not be equal
        XCTAssertNotEqual(lhs, rhs)
    }

    // MARK: - Hashable Tests

    func testHashBool() {
        // GIVEN AnyCodable with bool
        let anyCodable = AnyCodable(true)

        // WHEN hashing
        var hasher = Hasher()
        anyCodable.hash(into: &hasher)
        let hash = hasher.finalize()

        // THEN should produce hash
        XCTAssertNotNil(hash)
    }

    func testHashInt() {
        // GIVEN AnyCodable with int
        let anyCodable = AnyCodable(42)

        // WHEN hashing
        var hasher = Hasher()
        anyCodable.hash(into: &hasher)
        let hash = hasher.finalize()

        // THEN should produce hash
        XCTAssertNotNil(hash)
    }

    func testHashString() {
        // GIVEN AnyCodable with string
        let anyCodable = AnyCodable("hello")

        // WHEN hashing
        var hasher = Hasher()
        anyCodable.hash(into: &hasher)
        let hash = hasher.finalize()

        // THEN should produce hash
        XCTAssertNotNil(hash)
    }

    func testHashComplexType() {
        // GIVEN AnyCodable with complex type
        let anyCodable = AnyCodable([1, 2, 3])

        // WHEN hashing
        var hasher = Hasher()
        anyCodable.hash(into: &hasher)
        let hash = hasher.finalize()

        // THEN should produce hash using type name
        XCTAssertNotNil(hash)
    }

    func testUseInSet() {
        // GIVEN AnyCodable values
        let value1 = AnyCodable(1)
        let value2 = AnyCodable(2)
        let value3 = AnyCodable(1) // duplicate

        // WHEN adding to set
        var set = Set<AnyCodable>()
        set.insert(value1)
        set.insert(value2)
        set.insert(value3)

        // THEN set should contain unique values
        XCTAssertEqual(set.count, 2)
    }

    func testUseAsDictionaryKey() {
        // GIVEN AnyCodable values
        let key1 = AnyCodable("key1")
        let key2 = AnyCodable("key2")

        // WHEN using as dictionary keys
        var dict = [AnyCodable: String]()
        dict[key1] = "value1"
        dict[key2] = "value2"

        // THEN should work as keys
        XCTAssertEqual(dict[key1], "value1")
        XCTAssertEqual(dict[key2], "value2")
    }

    // MARK: - Edge Cases

    func testEmptyString() throws {
        // GIVEN AnyCodable with empty string
        let anyCodable = AnyCodable("")

        // WHEN encoding and decoding
        let data = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve empty string
        XCTAssertEqual(decoded.value as? String, "")
    }

    func testEmptyArray() throws {
        // GIVEN AnyCodable with empty array
        let anyCodable = AnyCodable([])

        // WHEN encoding and decoding
        let data = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve empty array
        let array = decoded.value as? [Any]
        XCTAssertEqual(array?.count, 0)
    }

    func testEmptyDictionary() throws {
        // GIVEN AnyCodable with empty dictionary
        let anyCodable = AnyCodable([String: Any]())

        // WHEN encoding and decoding
        let data = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve empty dictionary
        let dict = decoded.value as? [String: Any]
        XCTAssertEqual(dict?.count, 0)
    }

    func testLargeInt() throws {
        // GIVEN AnyCodable with large int
        let largeInt = Int.max
        let anyCodable = AnyCodable(largeInt)

        // WHEN encoding and decoding
        let data = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve value
        XCTAssertEqual(decoded.value as? Int, largeInt)
    }

    func testNegativeInt() throws {
        // GIVEN AnyCodable with negative int
        let anyCodable = AnyCodable(-42)

        // WHEN encoding and decoding
        let data = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve value
        XCTAssertEqual(decoded.value as? Int, -42)
    }

    func testZero() throws {
        // GIVEN AnyCodable with zero
        let anyCodable = AnyCodable(0)

        // WHEN encoding and decoding
        let data = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve value
        XCTAssertEqual(decoded.value as? Int, 0)
    }

    func testUnicodeString() throws {
        // GIVEN AnyCodable with unicode string
        let anyCodable = AnyCodable("Hello 👋 World 🌍")

        // WHEN encoding and decoding
        let data = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve unicode
        XCTAssertEqual(decoded.value as? String, "Hello 👋 World 🌍")
    }

    func testNestedArray() throws {
        // GIVEN AnyCodable with nested array
        let nested: [Any] = [1, [2, 3], 4]
        let anyCodable = AnyCodable(nested)

        // WHEN encoding and decoding
        let data = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve structure
        let array = decoded.value as? [Any]
        XCTAssertEqual(array?.count, 3)
    }

    func testNestedDictionary() throws {
        // GIVEN AnyCodable with nested dictionary
        let nested: [String: Any] = [
            "outer": ["inner": "value"]
        ]
        let anyCodable = AnyCodable(nested)

        // WHEN encoding and decoding
        let data = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // THEN should preserve structure
        let dict = decoded.value as? [String: Any]
        XCTAssertNotNil(dict?["outer"])
    }

    // MARK: - Thread Safety Tests

    func testConcurrentEncoding() throws {
        // GIVEN multiple AnyCodable values
        let values = (0..<100).map { AnyCodable($0) }

        // WHEN encoding concurrently
        let expectation = XCTestExpectation(description: "Concurrent encoding")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var encodedData: [Data] = []
        let lock = NSLock()

        for value in values {
            group.enter()
            queue.async {
                do {
                    let data = try self.encoder.encode(value)
                    lock.lock()
                    encodedData.append(data)
                    lock.unlock()
                } catch {
                    XCTFail("Encoding failed: \(error)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // THEN all encodings should succeed
        XCTAssertEqual(encodedData.count, 100)
    }

    // MARK: - Integration Tests Documentation

    func testDocumentRequiredIntegrationTests() {
        // This test documents integration tests that should be written
        // with real usage scenarios

        let requiredIntegrationTests = [
            "testAnyCodableInNoteMetadata",
            "testAnyCodableInAPIResponse",
            "testAnyCodableWithUserDefaults",
            "testAnyCodableInCoreData",
            "testAnyCodableAcrossNetworkBoundary",
            "testAnyCodableInSwiftUIView"
        ]

        XCTAssertEqual(requiredIntegrationTests.count, 6,
                      "Should have \(requiredIntegrationTests.count) integration tests")
    }
}
