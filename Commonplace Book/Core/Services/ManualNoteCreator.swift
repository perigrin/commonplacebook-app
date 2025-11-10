// ABOUTME: Service for creating notes from manual text input with auto-title generation
// ABOUTME: Handles title extraction from content, metadata collection, and note persistence

import Foundation

/// Service for creating notes from manual text input
@MainActor
class ManualNoteCreator {

    // MARK: - Dependencies

    private let repository: NoteRepository
    private let metadataCollector: MetadataCollector
    private let titleGenerator: TitleGenerator

    // MARK: - Static Properties

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Initialization

    init(repository: NoteRepository, metadataCollector: MetadataCollector, titleGenerator: TitleGenerator? = nil) {
        self.repository = repository
        self.metadataCollector = metadataCollector
        self.titleGenerator = titleGenerator ?? TitleGenerator()
    }

    // MARK: - Note Creation

    /// Create a note from manual text input
    /// - Parameters:
    ///   - title: Optional title. If nil or empty, auto-generated from content
    ///   - content: Note content (markdown)
    /// - Returns: Created note with metadata
    /// - Throws: ManualNoteCreatorError.emptyContent if content is empty
    func createNote(title: String?, content: String) async throws -> Note {
        // Validate content is not empty
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw ManualNoteCreatorError.emptyContent
        }

        // Generate title if not provided
        let finalTitle = generateTitle(from: title, content: trimmedContent)

        // Collect metadata
        let device = metadataCollector.getCurrentDevice()
        let timestamp = metadataCollector.generateTimestamp()
        let location = await metadataCollector.getCurrentLocation()

        // Create note
        let note = Note(
            id: UUID(),
            created: timestamp,
            device: device,
            location: location,
            content: trimmedContent,
            title: finalTitle,
            backlinks: [],
            unknownFrontmatterFields: [:]
        )

        // Save to repository
        return try await repository.create(note: note)
    }

    // MARK: - Private Helpers

    /// Generate title from provided title or content
    private func generateTitle(from title: String?, content: String) -> String {
        // Check if title was provided and is not empty/whitespace
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title.truncated(to: 100)
        }

        // Auto-generate from content
        return extractTitleFromContent(content)
    }

    /// Extract title from content using TitleGenerator
    private func extractTitleFromContent(_ content: String) -> String {
        // Use TitleGenerator for smart title extraction
        return titleGenerator.generateTitle(from: content)
    }
}

/// Errors specific to manual note creation
enum ManualNoteCreatorError: LocalizedError {
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Note content cannot be empty"
        }
    }
}
