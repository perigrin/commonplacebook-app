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
    private let maxRetries: Int = 3

    private var processingQueue: [UUID] = []
    private var processedNotes: Set<UUID> = []
    private var successfulNotes: Set<UUID> = []
    private var failedNotes: [UUID: Int] = [:] // noteId -> retry count
    private var embeddings: [UUID: [Float]] = [:]
    private var processingTask: Task<Void, Never>?
    private var totalNotesToProcess: Int = 0
    private var notesProcessedCount: Int = 0

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
        // Skip if already processed successfully
        guard !processedNotes.contains(id) else { return }

        // Add to queue if not already queued
        if !processingQueue.contains(id) {
            processingQueue.append(id)
            totalNotesToProcess += 1
            updateProgress()
        }
    }

    // MARK: - Private Methods

    /// Process queued notes in batches
    private func processQueue() async {
        while !Task.isCancelled && await MainActor.run({ isProcessing }) {
            // Get next batch atomically
            let batch = await MainActor.run { () -> [UUID] in
                guard !processingQueue.isEmpty else { return [] }
                let batchSize = min(self.batchSize, processingQueue.count)
                let extracted = Array(processingQueue.prefix(batchSize))
                processingQueue.removeFirst(batchSize)
                return extracted
            }

            guard !batch.isEmpty else { break }

            // Process batch
            await processBatch(batch)

            // Update progress after batch
            await MainActor.run {
                updateProgress()
            }

            // Check cancellation after batch
            if Task.isCancelled {
                break
            }

            // Small delay between batches
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
        var batchUpdates: [(UUID, [Float])] = []

        for noteId in batch {
            // Skip if already processed successfully
            if await MainActor.run({ processedNotes.contains(noteId) }) {
                continue
            }

            do {
                // Fetch note content
                guard let note = try await noteRepository.read(id: noteId) else {
                    continue
                }

                // Generate embedding
                let embedding = try await embeddingService.generateEmbedding(for: note.content)

                // Collect for batch update
                batchUpdates.append((noteId, embedding))

            } catch {
                // Log error and handle retry
                print("Error processing note \(noteId): \(error)")

                await MainActor.run {
                    let retryCount = failedNotes[noteId] ?? 0
                    if retryCount < maxRetries {
                        // Retry with exponential backoff
                        failedNotes[noteId] = retryCount + 1
                        processingQueue.append(noteId)
                    } else {
                        // Max retries exceeded, mark as processed
                        processedNotes.insert(noteId)
                        failedNotes.removeValue(forKey: noteId)
                        notesProcessedCount += 1
                    }
                }
            }
        }

        // Apply batch updates atomically on MainActor
        await MainActor.run {
            for (noteId, embedding) in batchUpdates {
                embeddings[noteId] = embedding
                processedNotes.insert(noteId)
                successfulNotes.insert(noteId)
                notesProcessedCount += 1
                failedNotes.removeValue(forKey: noteId)
            }
        }

        // Index all successful embeddings in search engine
        for (noteId, embedding) in batchUpdates {
            try? await searchEngine.indexNote(id: noteId, embedding: embedding)
        }

        // Persist ONCE after entire batch
        if !batchUpdates.isEmpty {
            await persistEmbeddings()
        }
    }

    /// Update progress based on processed count
    private func updateProgress() {
        guard totalNotesToProcess > 0 else {
            progress = 1.0
            return
        }

        progress = Float(notesProcessedCount) / Float(totalNotesToProcess)
    }

    // MARK: - Persistence

    /// Persist embeddings to disk
    private func persistEmbeddings() async {
        do {
            let embeddingsFile = storageDirectory.appendingPathComponent("embeddings.json")

            // Get snapshot of embeddings on MainActor
            let embeddingsSnapshot = await MainActor.run { embeddings }

            // Convert embeddings to serializable format
            let data: [String: [Float]] = embeddingsSnapshot.reduce(into: [:]) { result, pair in
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

            // Convert back to UUID keys and update state on MainActor
            var loadedEmbeddings: [UUID: [Float]] = [:]
            var loadedProcessed: Set<UUID> = []
            var loadedSuccessful: Set<UUID> = []

            for (key, value) in data {
                if let uuid = UUID(uuidString: key) {
                    loadedEmbeddings[uuid] = value
                    loadedProcessed.insert(uuid)
                    loadedSuccessful.insert(uuid)
                }
            }

            await MainActor.run {
                embeddings = loadedEmbeddings
                processedNotes = loadedProcessed
                successfulNotes = loadedSuccessful
                notesProcessedCount = loadedSuccessful.count
            }

            // Re-index all loaded embeddings
            for (noteId, embedding) in loadedEmbeddings {
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
