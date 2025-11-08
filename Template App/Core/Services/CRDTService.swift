// ABOUTME: Service for CRDT-based note synchronization using Automerge
// ABOUTME: Provides conflict-free merging with last-write-wins for scalars and union for backlinks

import Foundation
import Automerge

/// Errors that can occur during CRDT operations
enum CRDTServiceError: Error {
    case emptyDocument
    case missingRequiredField(String)
}

/// Type alias for Automerge document handle
typealias DocHandle = Document

/// Service for managing CRDT-based note synchronization
/// Thread-safe actor-based implementation for concurrent access
actor CRDTService {

    // MARK: - Document Creation

    /// Create a new empty Automerge document
    /// - Returns: New document handle
    func createDocument() -> DocHandle {
        return Document()
    }

    // MARK: - Note Operations

    /// Update a note in an Automerge document
    /// - Parameters:
    ///   - docHandle: The document to update
    ///   - note: The note to write
    /// - Throws: CRDTServiceError if update fails
    func updateNote(docHandle: DocHandle, note: Note) throws {
        // Set scalar fields (last-write-wins semantics)
        try docHandle.put(obj: .ROOT, key: "id", value: .String(note.id.uuidString))
        try docHandle.put(obj: .ROOT, key: "created", value: .Int(Int64(note.created.timeIntervalSince1970)))
        try docHandle.put(obj: .ROOT, key: "device", value: .String(note.device))
        try docHandle.put(obj: .ROOT, key: "content", value: .String(note.content))
        try docHandle.put(obj: .ROOT, key: "title", value: .String(note.title))

        // Handle location (optional Map)
        if let location = note.location {
            let locationObj = try docHandle.putObject(obj: .ROOT, key: "location", ty: .Map)
            try docHandle.put(obj: locationObj, key: "latitude", value: .F64(location.latitude))
            try docHandle.put(obj: locationObj, key: "longitude", value: .F64(location.longitude))
            try docHandle.put(obj: locationObj, key: "accuracy", value: .F64(location.accuracy))
        } else {
            // Remove location if nil (check if it exists first to avoid errors)
            if (try? docHandle.get(obj: .ROOT, key: "location")) != nil {
                try docHandle.delete(obj: .ROOT, key: "location")
            }
        }

        // Handle backlinks with union semantics
        // Sort backlinks for deterministic ordering (critical for CRDT consistency)
        let sortedBacklinks = note.backlinks.sorted { $0.uuidString < $1.uuidString }

        // Get or create backlinks list
        let backlinksObj: ObjId
        if let existingBacklinks = try? docHandle.get(obj: .ROOT, key: "backlinks"),
           case .Object(let obj, .List) = existingBacklinks {
            backlinksObj = obj

            // Read existing backlinks
            let existingCount = docHandle.length(obj: backlinksObj)
            var existingBacklinkStrings = Set<String>()
            for index in 0..<existingCount {
                if let itemValue = try? docHandle.get(obj: backlinksObj, index: UInt64(index)),
                   case .Scalar(.String(let backlinkString)) = itemValue {
                    existingBacklinkStrings.insert(backlinkString)
                }
            }

            // Add new backlinks that don't exist (union semantics)
            for backlink in sortedBacklinks {
                let backlinkString = backlink.uuidString
                if !existingBacklinkStrings.contains(backlinkString) {
                    // Append to end for CRDT consistency
                    try docHandle.insert(obj: backlinksObj, index: UInt64(existingCount + existingBacklinkStrings.count), value: .String(backlinkString))
                }
            }
        } else {
            // Create new backlinks list
            backlinksObj = try docHandle.putObject(obj: .ROOT, key: "backlinks", ty: .List)

            // Insert all backlinks
            for (index, backlink) in sortedBacklinks.enumerated() {
                try docHandle.insert(obj: backlinksObj, index: UInt64(index), value: .String(backlink.uuidString))
            }
        }
    }

    /// Read a note from an Automerge document
    /// - Parameter docHandle: The document to read from
    /// - Returns: The note
    /// - Throws: CRDTServiceError if document is empty or invalid
    func readNote(docHandle: DocHandle) throws -> Note {
        // Check if document has required fields
        guard let idValue = try? docHandle.get(obj: .ROOT, key: "id") else {
            throw CRDTServiceError.emptyDocument
        }

        // Extract ID
        guard case .Scalar(.String(let idString)) = idValue,
              let id = UUID(uuidString: idString) else {
            throw CRDTServiceError.missingRequiredField("id")
        }

        // Extract created timestamp
        guard let createdValue = try? docHandle.get(obj: .ROOT, key: "created"),
              case .Scalar(.Int(let createdTimestamp)) = createdValue else {
            throw CRDTServiceError.missingRequiredField("created")
        }
        let created = Date(timeIntervalSince1970: TimeInterval(createdTimestamp))

        // Extract device
        guard let deviceValue = try? docHandle.get(obj: .ROOT, key: "device"),
              case .Scalar(.String(let device)) = deviceValue else {
            throw CRDTServiceError.missingRequiredField("device")
        }

        // Extract content
        guard let contentValue = try? docHandle.get(obj: .ROOT, key: "content"),
              case .Scalar(.String(let content)) = contentValue else {
            throw CRDTServiceError.missingRequiredField("content")
        }

        // Extract title
        guard let titleValue = try? docHandle.get(obj: .ROOT, key: "title"),
              case .Scalar(.String(let title)) = titleValue else {
            throw CRDTServiceError.missingRequiredField("title")
        }

        // Extract location (optional)
        var location: Location? = nil
        if let locationValue = try? docHandle.get(obj: .ROOT, key: "location"),
           case .Object(let locationObj, .Map) = locationValue {
            if let latValue = try? docHandle.get(obj: locationObj, key: "latitude"),
               case .Scalar(.F64(let latitude)) = latValue,
               let lngValue = try? docHandle.get(obj: locationObj, key: "longitude"),
               case .Scalar(.F64(let longitude)) = lngValue,
               let accValue = try? docHandle.get(obj: locationObj, key: "accuracy"),
               case .Scalar(.F64(let accuracy)) = accValue {
                location = Location(
                    latitude: latitude,
                    longitude: longitude,
                    accuracy: accuracy
                )
            }
        }

        // Extract backlinks (return as Set to match Note model)
        var backlinks: Set<UUID> = []
        if let backlinksValue = try? docHandle.get(obj: .ROOT, key: "backlinks"),
           case .Object(let backlinksObj, .List) = backlinksValue {
            let count = docHandle.length(obj: backlinksObj)
            for index in 0..<count {
                if let itemValue = try? docHandle.get(obj: backlinksObj, index: UInt64(index)),
                   case .Scalar(.String(let backlinkString)) = itemValue,
                   let backlinkId = UUID(uuidString: backlinkString) {
                    backlinks.insert(backlinkId)
                }
            }
        }

        return Note(
            id: id,
            created: created,
            device: device,
            location: location,
            content: content,
            title: title,
            backlinks: backlinks,
            unknownFrontmatterFields: [:]
        )
    }

    // MARK: - Merge Operations

    /// Merge two Automerge documents
    /// - Parameters:
    ///   - doc1: First document
    ///   - doc2: Second document
    /// - Returns: Merged document
    /// - Throws: Error if merge fails
    /// - Note: Creates a fork of doc1 to preserve original documents (immutability)
    func merge(doc1: DocHandle, doc2: DocHandle) throws -> DocHandle {
        // Create a fork of doc1 to preserve it
        let merged = doc1.fork()

        // Merge doc2 into the forked document (propagate errors)
        try merged.merge(other: doc2)

        return merged
    }

    // MARK: - Serialization

    /// Save an Automerge document to Data
    /// - Parameter docHandle: The document to save
    /// - Returns: Serialized document data
    func save(docHandle: DocHandle) -> Data {
        return docHandle.save()
    }

    /// Load an Automerge document from Data
    /// - Parameter data: Serialized document data
    /// - Returns: Loaded document handle
    /// - Throws: Error if deserialization fails
    func load(data: Data) throws -> DocHandle {
        return try Document(data)
    }
}
