// ABOUTME: Background service for generating note embeddings asynchronously
// ABOUTME: Queues notes, processes in batches, persists embeddings, and tracks progress

import Foundation
import Combine

/// Service for generating embeddings in the background
@MainActor
class EmbeddingBackgroundService {

    // MARK: - Published Properties

    @Published private(set) var progress: Float = 1.0
    @Published private(set) var isProcessing: Bool = false

    // MARK: - Private Properties

    private let embeddingService: EmbeddingServiceProtocol
    private let noteRepository: NoteRepository
    private let searchEngine: VectorSearchEngine
    private let storageDirectory: URL
    private let batchSize: Int

    private var processingQueue: [UUID] = []
    private var processedNotes: Set<UUID> = []
    private var embeddings: [UUID: [Float]] = [:]
    private var processingTask: Task<Void, Never>?

    // MARK: - Initialization

    init(embeddingService: EmbeddingServiceProtocol,
         noteRepository: NoteRepository,
         searchEngine: VectorSearchEngine,
         storageDirectory: URL? = nil,
         batchSize: Int = 10) {
        self.embeddingService = embeddingService
        self.noteRepository = noteRepository
        self.searchEngine = searchEngine
        self.storageDirectory = storageDirectory ?? Self.defaultStorageDirectory()
        self.batchSize = batchSize

        // Load existing embeddings
        Task {
            await loadEmbeddings()
        }
    }

    // MARK: - Public Methods

    /// Start background processing
    func start() async {
        guard !isProcessing else { return }

        isProcessing = true

        // Start processing task with low priority
        processingTask = Task(priority: .low) {
            await processQueue()
        }
    }

    /// Stop background processing
    func stop() async {
        isProcessing = false

        // Cancel processing task
        processingTask?.cancel()
        processingTask = nil
    }

    /// Queue a note for embedding generation
    /// - Parameter id: Note UUID to queue
    func queueNote(id: UUID) async {
        // Skip if already processed
        guard !processedNotes.contains(id) else { return }

        // Add to queue if not already queued
        if !processingQueue.contains(id) {
            processingQueue.append(id)
            updateProgress()
        }
    }

    // MARK: - Private Methods

    /// Process queued notes in batches
    private func processQueue() async {
        while isProcessing && !processingQueue.isEmpty {
            // Get next batch
            let batchSize = min(self.batchSize, processingQueue.count)
            let batch = Array(processingQueue.prefix(batchSize))

            // Process batch
            await processBatch(batch)

            // Remove processed notes from queue
            await MainActor.run {
                processingQueue.removeFirst(batchSize)
                updateProgress()
            }

            // Small delay between batches to avoid overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        // Processing complete
        await MainActor.run {
            isProcessing = false
            progress = 1.0
        }
    }

    /// Process a batch of notes
    /// - Parameter batch: Array of note UUIDs to process
    private func processBatch(_ batch: [UUID]) async {
        for noteId in batch {
            // Skip if already processed
            guard !processedNotes.contains(noteId) else { continue }

            do {
                // Fetch note content
                guard let note = try await noteRepository.read(id: noteId) else {
                    continue
                }

                // Generate embedding
                let embedding = try await embeddingService.generateEmbedding(for: note.content)

                // Store embedding
                await MainActor.run {
                    embeddings[noteId] = embedding
                    processedNotes.insert(noteId)
                }

                // Index in search engine
                try await searchEngine.indexNote(id: noteId, embedding: embedding)

                // Persist after each successful generation
                await persistEmbeddings()

            } catch {
                // Log error and continue processing
                print("Error processing note \(noteId): \(error)")
                // Note remains in processedNotes to avoid infinite retries
                await MainActor.run {
                    processedNotes.insert(noteId)
                }
            }
        }
    }

    /// Update progress based on queue length
    private func updateProgress() {
        let total = processingQueue.count + processedNotes.count
        guard total > 0 else {
            progress = 1.0
            return
        }

        progress = Float(processedNotes.count) / Float(total)
    }

    // MARK: - Persistence

    /// Persist embeddings to disk
    private func persistEmbeddings() async {
        do {
            let embeddingsFile = storageDirectory.appendingPathComponent("embeddings.json")

            // Convert embeddings to serializable format
            let data: [String: [Float]] = embeddings.reduce(into: [:]) { result, pair in
                result[pair.key.uuidString] = pair.value
            }

            let jsonData = try JSONEncoder().encode(data)

            // Ensure directory exists
            try FileManager.default.createDirectory(at: storageDirectory,
                                                   withIntermediateDirectories: true)

            try jsonData.write(to: embeddingsFile)

        } catch {
            print("Error persisting embeddings: \(error)")
        }
    }

    /// Load embeddings from disk
    private func loadEmbeddings() async {
        do {
            let embeddingsFile = storageDirectory.appendingPathComponent("embeddings.json")

            guard FileManager.default.fileExists(atPath: embeddingsFile.path) else {
                return
            }

            let jsonData = try Data(contentsOf: embeddingsFile)
            let data = try JSONDecoder().decode([String: [Float]].self, from: jsonData)

            // Convert back to UUID keys
            await MainActor.run {
                embeddings = data.reduce(into: [:]) { result, pair in
                    if let uuid = UUID(uuidString: pair.key) {
                        result[uuid] = pair.value
                        processedNotes.insert(uuid)
                    }
                }
            }

            // Re-index all loaded embeddings
            for (noteId, embedding) in embeddings {
                try? await searchEngine.indexNote(id: noteId, embedding: embedding)
            }

        } catch {
            print("Error loading embeddings: \(error)")
        }
    }

    /// Get default storage directory
    private static func defaultStorageDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Embeddings")
    }
}
