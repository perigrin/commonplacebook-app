// ABOUTME: Thread-safe LRU cache for embeddings using Swift actor model
// ABOUTME: Provides atomic cache operations with proper eviction and memory management

import Foundation

/// Thread-safe LRU cache for embedding vectors
actor EmbeddingCache {

    // MARK: - Properties

    private var cache: [String: [Float]] = [:]
    private var accessOrder: [String] = []
    private let maxSize: Int

    // MARK: - Initialization

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    // MARK: - Cache Operations

    /// Get embedding from cache, updating LRU order
    /// - Parameter key: Cache key (typically the input text)
    /// - Returns: Cached embedding if exists, nil otherwise
    func get(_ key: String) -> [Float]? {
        guard let embedding = cache[key] else {
            return nil
        }

        // Update access order (move to end)
        updateAccessOrder(for: key)

        return embedding
    }

    /// Put embedding in cache with LRU eviction
    /// - Parameters:
    ///   - key: Cache key (typically the input text)
    ///   - embedding: Embedding vector to cache
    func put(_ key: String, _ embedding: [Float]) {
        // Evict oldest if cache is full and key is new
        if cache.count >= maxSize && cache[key] == nil {
            evictOldest()
        }

        // Store embedding
        cache[key] = embedding

        // Update access order
        updateAccessOrder(for: key)
    }

    /// Clear all cached embeddings
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    /// Get current cache size
    func size() -> Int {
        return cache.count
    }

    // MARK: - Private Helpers

    /// Update access order by moving key to end (most recently used)
    private func updateAccessOrder(for key: String) {
        // Remove key from current position if exists
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }

        // Add to end (most recently used)
        accessOrder.append(key)
    }

    /// Evict least recently used item
    private func evictOldest() {
        guard let oldestKey = accessOrder.first else { return }

        cache.removeValue(forKey: oldestKey)
        accessOrder.removeFirst()
    }
}
