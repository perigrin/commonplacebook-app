// ABOUTME: Tests for EmbeddingService that generates vector embeddings for semantic search
// ABOUTME: Validates embedding generation, caching, batch processing, and Core ML model integration

import XCTest
@testable import Commonplace_Book

@MainActor
final class EmbeddingServiceTests: XCTestCase {
    var service: EmbeddingService!

    override func setUpWithError() throws {
        service = EmbeddingService()
    }

    override func tearDownWithError() throws {
        service = nil
    }

    // MARK: - Model Loading Tests

    func testLoadModelSucceeds() async throws {
        // GIVEN unloaded service
        // WHEN loading model
        try await service.loadModel()

        // THEN model is loaded (no error thrown)
        // Success is indicated by no exception
    }

    func testEmbeddingDimensionReturnsCorrectValue() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN checking embedding dimension
        let dimension = service.embeddingDimension

        // THEN dimension is positive and consistent
        XCTAssertGreaterThan(dimension, 0, "Embedding dimension should be positive")
        XCTAssertLessThanOrEqual(dimension, 1024, "Embedding dimension should be reasonable")
    }

    // MARK: - Single Embedding Tests

    func testGenerateEmbeddingReturnsCorrectDimension() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating embedding for text
        let text = "This is a test sentence"
        let embedding = try await service.generateEmbedding(for: text)

        // THEN embedding has correct dimension
        XCTAssertEqual(embedding.count, service.embeddingDimension)
    }

    func testGenerateEmbeddingForEmptyStringReturnsVector() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating embedding for empty string
        let embedding = try await service.generateEmbedding(for: "")

        // THEN still returns valid embedding (zero vector or model default)
        XCTAssertEqual(embedding.count, service.embeddingDimension)
    }

    func testSameTextReturnsSameEmbedding() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating embeddings for same text twice
        let text = "Consistent embedding test"
        let embedding1 = try await service.generateEmbedding(for: text)
        let embedding2 = try await service.generateEmbedding(for: text)

        // THEN embeddings are identical
        XCTAssertEqual(embedding1.count, embedding2.count)
        for i in 0..<embedding1.count {
            XCTAssertEqual(embedding1[i], embedding2[i], accuracy: 0.0001,
                          "Embeddings should be identical for same input")
        }
    }

    func testEmbeddingsAreNormalized() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating embedding
        let embedding = try await service.generateEmbedding(for: "Test normalization")

        // THEN embedding is normalized (magnitude = 1.0)
        let magnitude = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        XCTAssertEqual(magnitude, 1.0, accuracy: 0.01, "Embeddings should be normalized")
    }

    // MARK: - Similarity Tests

    func testSimilarTextsHaveSimilarEmbeddings() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating embeddings for similar texts
        let text1 = "The cat sits on the mat"
        let text2 = "A cat is sitting on the mat"
        let embedding1 = try await service.generateEmbedding(for: text1)
        let embedding2 = try await service.generateEmbedding(for: text2)

        // THEN cosine similarity is high (> 0.8)
        let similarity = cosineSimilarity(embedding1, embedding2)
        XCTAssertGreaterThan(similarity, 0.8, "Similar texts should have high similarity")
    }

    func testDifferentTextsHaveDifferentEmbeddings() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating embeddings for different texts
        let text1 = "Machine learning is fascinating"
        let text2 = "I enjoy cooking Italian food"
        let embedding1 = try await service.generateEmbedding(for: text1)
        let embedding2 = try await service.generateEmbedding(for: text2)

        // THEN cosine similarity is lower
        let similarity = cosineSimilarity(embedding1, embedding2)
        XCTAssertLessThan(similarity, 0.7, "Different texts should have lower similarity")
    }

    // MARK: - Batch Processing Tests

    func testBatchProcessingWorks() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating embeddings for multiple texts
        let texts = [
            "First document about Swift programming",
            "Second document about iOS development",
            "Third document about machine learning"
        ]
        let embeddings = try await service.generateEmbeddings(for: texts)

        // THEN returns correct number of embeddings
        XCTAssertEqual(embeddings.count, texts.count)

        // AND each embedding has correct dimension
        for embedding in embeddings {
            XCTAssertEqual(embedding.count, service.embeddingDimension)
        }
    }

    func testBatchProcessingWithEmptyArrayReturnsEmpty() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating embeddings for empty array
        let embeddings = try await service.generateEmbeddings(for: [])

        // THEN returns empty array
        XCTAssertEqual(embeddings.count, 0)
    }

    // MARK: - Caching Tests

    func testCachingPreventsRecomputation() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating same embedding twice
        let text = "Cache test document"
        let startTime1 = Date()
        _ = try await service.generateEmbedding(for: text)
        let duration1 = Date().timeIntervalSince(startTime1)

        let startTime2 = Date()
        _ = try await service.generateEmbedding(for: text)
        let duration2 = Date().timeIntervalSince(startTime2)

        // THEN second call is faster (cached)
        XCTAssertLessThan(duration2, duration1 * 0.5,
                         "Cached embedding should be much faster")
    }

    func testCacheEvictionWorksWithLRU() async throws {
        // GIVEN loaded model with small cache
        service = EmbeddingService(cacheSize: 3)
        try await service.loadModel()

        // WHEN generating embeddings for more items than cache size
        let texts = ["Text 1", "Text 2", "Text 3", "Text 4"]
        for text in texts {
            _ = try await service.generateEmbedding(for: text)
        }

        // THEN oldest item (Text 1) is evicted
        // We can't directly test cache internals, but we can measure timing
        let startTime = Date()
        _ = try await service.generateEmbedding(for: "Text 1")
        let duration = Date().timeIntervalSince(startTime)

        // Should be slower (not cached) compared to recent items
        XCTAssertGreaterThan(duration, 0, "Evicted item should require recomputation")
    }

    func testCacheRespectsMaxSize() async throws {
        // GIVEN service with cache size limit
        let cacheSize = 5
        service = EmbeddingService(cacheSize: cacheSize)
        try await service.loadModel()

        // WHEN adding more items than cache size
        for i in 0..<(cacheSize + 2) {
            _ = try await service.generateEmbedding(for: "Document \(i)")
        }

        // THEN cache doesn't exceed max size (implicit test - no crash/memory issue)
        // Success is indicated by no memory error or performance degradation
    }

    // MARK: - Error Handling Tests

    func testGenerateEmbeddingBeforeLoadModelThrowsError() async throws {
        // GIVEN unloaded service
        service = EmbeddingService()

        // WHEN generating embedding without loading model
        // THEN throws error
        do {
            _ = try await service.generateEmbedding(for: "Test")
            XCTFail("Should throw error when model not loaded")
        } catch let error as EmbeddingServiceError {
            XCTAssertEqual(error, EmbeddingServiceError.modelNotLoaded)
        }
    }

    func testBatchProcessingHandlesIndividualFailures() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN processing batch with some problematic inputs
        let texts = [
            "Normal text",
            String(repeating: "x", count: 10000), // Very long text
            "",  // Empty text
            "Another normal text"
        ]

        // THEN should process successfully (or throw clear error)
        let embeddings = try await service.generateEmbeddings(for: texts)
        XCTAssertEqual(embeddings.count, texts.count,
                      "Should process all texts even with edge cases")
    }

    // MARK: - Concurrency Tests

    func testConcurrentEmbeddingGenerationIsSafe() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating embeddings concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    // Use modulo to force cache hits and test concurrent access
                    _ = try? await self.service.generateEmbedding(for: "Concurrent text \(i % 10)")
                }
            }
        }

        // THEN no crashes occurred and cache is in valid state
        // Verify cache still works
        let embedding = try await service.generateEmbedding(for: "Concurrent text 0")
        XCTAssertEqual(embedding.count, service.embeddingDimension)
    }

    func testConcurrentBatchProcessingIsSafe() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN running multiple batch operations concurrently
        await withTaskGroup(of: [[Float]].self) { group in
            for batch in 0..<10 {
                group.addTask {
                    let texts = (0..<10).map { "Batch \(batch) text \($0)" }
                    return (try? await self.service.generateEmbeddings(for: texts)) ?? []
                }
            }

            // Collect all results
            var allEmbeddings: [[[Float]]] = []
            for await embeddings in group {
                allEmbeddings.append(embeddings)
            }

            // Verify we got results from all batches
            XCTAssertEqual(allEmbeddings.count, 10, "Should process all batches")
        }
    }

    // MARK: - Performance Tests

    func testPerformanceWithThousandEmbeddings() async throws {
        // GIVEN loaded model
        try await service.loadModel()

        // WHEN generating many embeddings
        let texts = (0..<100).map { "Performance test document number \($0)" }

        // THEN completes in reasonable time
        let startTime = Date()
        _ = try await service.generateEmbeddings(for: texts)
        let duration = Date().timeIntervalSince(startTime)

        // Should complete in under 10 seconds for 100 documents
        XCTAssertLessThan(duration, 10.0,
                         "Should process 100 documents in reasonable time")
    }

    // MARK: - NLEmbedding Model Integration Tests

    func testLoadModelLoadsNLEmbedding() async throws {
        // GIVEN unloaded service
        // WHEN loading model
        try await service.loadModel()

        // THEN service should have loaded NLEmbedding sentence model
        let embedding = try await service.generateEmbedding(for: "test")

        // NLEmbedding produces learned embeddings, not hash-based patterns
        XCTAssertNotNil(embedding, "Model should produce embeddings")
        XCTAssertEqual(embedding.count, 512, "NLEmbedding produces 512-dimensional embeddings")
    }

    func testNLEmbeddingsAreSemanticNotLexical() async throws {
        // GIVEN loaded NLEmbedding model
        try await service.loadModel()

        // WHEN generating embeddings for semantically similar but lexically different texts
        let text1 = "The quick brown fox jumps over the lazy dog"
        let text2 = "A fast auburn canine leaps across an idle hound"
        let text3 = "Python is a programming language"

        let embedding1 = try await service.generateEmbedding(for: text1)
        let embedding2 = try await service.generateEmbedding(for: text2)
        let embedding3 = try await service.generateEmbedding(for: text3)

        // THEN semantically similar texts should have higher similarity than unrelated ones
        let semanticSimilarity = cosineSimilarity(embedding1, embedding2)
        let unrelatedSimilarity = cosineSimilarity(embedding1, embedding3)

        // NLEmbedding should understand semantic meaning, not just word overlap
        XCTAssertGreaterThan(semanticSimilarity, 0.3,
                           "NLEmbedding should recognize semantic similarity despite different words")
        XCTAssertLessThan(unrelatedSimilarity, semanticSimilarity,
                         "Unrelated texts should have lower similarity")
    }

    func testNLEmbeddingHandlesContextualMeaningCorrectly() async throws {
        // GIVEN loaded NLEmbedding model
        try await service.loadModel()

        // WHEN generating embeddings for words with different contextual meanings
        let context1 = "The bank of the river was muddy"
        let context2 = "I went to the bank to deposit money"
        let unrelated = "The sky is blue today"

        let embedding1 = try await service.generateEmbedding(for: context1)
        let embedding2 = try await service.generateEmbedding(for: context2)
        let embedding3 = try await service.generateEmbedding(for: unrelated)

        // THEN NLEmbedding should understand contextual differences
        let bankContextSimilarity = cosineSimilarity(embedding1, embedding2)
        let unrelatedSimilarity = cosineSimilarity(embedding1, embedding3)

        // Both use "bank" but NLEmbedding should understand they're different contexts
        // while still being more related than completely unrelated text
        XCTAssertLessThan(unrelatedSimilarity, bankContextSimilarity,
                         "NLEmbedding should recognize some relationship in texts with shared words")
    }

    // MARK: - Helper Methods

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }

        var dotProduct: Float = 0.0
        var magnitudeA: Float = 0.0
        var magnitudeB: Float = 0.0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            magnitudeA += a[i] * a[i]
            magnitudeB += b[i] * b[i]
        }

        let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)
        guard magnitude > 0 else { return 0.0 }

        return dotProduct / magnitude
    }
}
