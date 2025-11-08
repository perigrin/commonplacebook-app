# Commonplace Book / Zettelkasten iOS App - Build Plan

## Executive Summary

This document provides a comprehensive, step-by-step build plan for transforming the iOS template into a fully-functional Zettelkasten application. The plan emphasizes:

- **Test-Driven Development (TDD)**: Every feature begins with tests
- **Incremental Progress**: Small, safe steps that build on each other
- **No Orphaned Code**: Each step integrates fully with previous work
- **Early Testing**: Validation at every stage

## Project Overview

We're building an iOS app for managing a git-based Zettelkasten/Commonplace Book with:
- Speech-to-text note capture (offline)
- Vector search for discovery (offline)
- Git synchronization with SSH
- CRDT-based sync across devices via iCloud
- Claude AI integration (post-MVP)

**Source of Truth**: CRDT database, with git as "just another client"

## Architecture Blueprint

### Core Components

1. **Data Layer**
   - CRDT database (Automerge-based)
   - Core Data wrapper for SwiftUI integration
   - Git repository interface
   - Note model with metadata

2. **Note Management**
   - UUID v7 generation
   - Markdown parsing and rendering
   - Frontmatter YAML handling
   - Backlink tracking

3. **Capture System**
   - Speech recognition (Apple Speech framework)
   - Text input
   - Metadata collection (location, device, timestamp)
   - Auto-title generation

4. **Discovery System**
   - Vector embeddings (Core ML)
   - Semantic search
   - Note list with infinite scroll
   - Filtering and sorting

5. **Sync Engine**
   - CRDT sync via iCloud
   - Git operations (commit, push, pull, merge)
   - SSH authentication
   - Conflict resolution

6. **UI Components**
   - Note list view
   - Note editor (raw markdown)
   - Capture interface
   - Settings and configuration

## Development Phases

### Phase 1: Foundation (Steps 1-8)
Set up core data models, file format, and basic CRUD operations

### Phase 2: Note Capture (Steps 9-14)
Implement speech recognition and text input for note creation

### Phase 3: Note Discovery (Steps 15-20)
Build search, filtering, and the note list UI

### Phase 4: Git Integration (Steps 21-26)
Add git sync, SSH authentication, and conflict resolution

### Phase 5: CRDT Sync (Steps 27-30)
Implement iCloud sync with CRDT

### Phase 6: Polish & Security (Steps 31-35)
Add biometric auth, encryption, trash, and final integration

---

## Detailed Step-by-Step Plan

### PHASE 1: FOUNDATION

#### Step 1: Note Data Model ✅ COMPLETED

**Goal**: Create the core Note model with all required metadata fields

**What to Build**:
- Note entity with UUID v7 identifier
- Fields: id, created, device, location (lat/lng/accuracy), content, title
- Backlinks array field
- Validation logic

**TDD Prompt**:

```
I'm building a Zettelkasten iOS app. We need to start with the core Note data model.

REQUIREMENTS:
- Create a Note struct/class with these fields:
  - id: UUID (v7, timestamp-based)
  - created: Date
  - device: String (e.g., "iPhone 15 Pro")
  - location: Optional struct with latitude, longitude, accuracy (all Double)
  - content: String (markdown content)
  - title: String
  - backlinks: [UUID] (array of note IDs that link to this note)

- UUID v7 generation: Create a helper to generate timestamp-ordered UUIDs (v7 spec)
- Device name: Helper to get current device name (e.g., "iPhone 15 Pro", "iPad Air")
- Validation: Ensure all required fields are present

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Note creation with all fields
   - UUID v7 generation (verify timestamp ordering)
   - Device name retrieval
   - Location struct creation
   - Backlinks array manipulation (add, remove)
   - Validation failures for missing required fields

2. Run tests to see them FAIL
3. Implement the minimal code to make tests PASS
4. All tests must pass at 100%

Use Swift and follow iOS best practices. No Core Data yet - pure Swift structs/classes.
```

---

#### Step 2: Markdown File Format Handler ✅ COMPLETED

**Goal**: Parse and serialize notes to/from markdown files with YAML frontmatter

**What to Build**:
- YAML frontmatter parser
- Markdown content separator
- Note serialization to string
- Note deserialization from string
- Extended markdown support detection

**TDD Prompt**:

```
Building on Step 1 (Note model), we need to handle the markdown file format.

REQUIREMENTS:
- Create NoteFileFormatter class with:
  - serialize(note: Note) -> String: Convert Note to markdown with YAML frontmatter
  - deserialize(content: String) -> Note: Parse markdown file into Note

- File format:
  ```
  ---
  id: <uuid>
  created: <ISO8601 timestamp>
  device: <device name>
  location:
    latitude: <double>
    longitude: <double>
    accuracy: <double>
  backlinks:
    - <uuid1>
    - <uuid2>
  ---

  # Note Title

  Markdown content here...
  ```

- Handle optional fields (location, backlinks can be missing)
- Preserve unknown frontmatter fields
- Support footnotes syntax in markdown

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Serialize note with all fields
   - Serialize note with minimal fields (no location/backlinks)
   - Deserialize complete note
   - Deserialize minimal note
   - Round-trip test (serialize -> deserialize -> equals)
   - Handle malformed YAML gracefully
   - Preserve unknown frontmatter fields

2. Run tests to see them FAIL
3. Implement using Swift Yams library for YAML
4. All tests must pass at 100%

Consider using SwiftUI's AttributedString for markdown if needed.
```

---

#### Step 3: Note Repository Interface ✅ COMPLETED

**Goal**: Create repository pattern for note CRUD operations (in-memory first)

**What to Build**:
- NoteRepository protocol
- InMemoryNoteRepository implementation
- CRUD operations: create, read, update, delete, list
- Query operations: find by ID, search by text

**TDD Prompt**:

```
Building on Steps 1-2, create a repository pattern for managing notes.

REQUIREMENTS:
- Define NoteRepository protocol with:
  - create(note: Note) async throws -> Note
  - read(id: UUID) async throws -> Note?
  - update(note: Note) async throws -> Note
  - delete(id: UUID) async throws
  - list() async throws -> [Note]
  - search(query: String) async throws -> [Note]

- Implement InMemoryNoteRepository:
  - Store notes in memory (Dictionary keyed by UUID)
  - Thread-safe access (use actor or @MainActor)
  - Return copies, not references
  - search() should do simple text matching in title/content

- Errors:
  - NoteNotFoundError
  - DuplicateNoteError
  - RepositoryError

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Create note successfully
   - Create duplicate note fails
   - Read existing note
   - Read non-existent note returns nil
   - Update existing note
   - Update non-existent note fails
   - Delete existing note
   - Delete non-existent note succeeds (idempotent)
   - List all notes
   - Search finds matching notes
   - Search returns empty for no matches
   - Concurrent access safety

2. Run tests to see them FAIL
3. Implement InMemoryNoteRepository
4. All tests must pass at 100%

Use Swift actors for thread safety.
```

---

#### Step 4: File System Note Storage ✅

**Goal**: Persist notes to disk as markdown files

**What to Build**:
- FileSystemNoteRepository implementation
- Directory structure management
- File naming (UUID.md)
- Atomic writes
- Directory scanning

**TDD Prompt**:

```
Building on Steps 1-3, implement file system persistence for notes.

REQUIREMENTS:
- Create FileSystemNoteRepository implementing NoteRepository protocol
- Store each note as: <uuid>.md in a configured directory
- Use NoteFileFormatter from Step 2 for serialization
- Atomic writes (write to temp file, then rename)
- Lazy loading: scan directory only when needed
- Cache in memory for performance

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Create note writes file to disk
   - File has correct name (<uuid>.md)
   - File content matches serialization
   - Read note from existing file
   - Update note overwrites file atomically
   - Delete note removes file
   - List scans directory and returns all notes
   - Search works across all files
   - Handles missing directory (creates it)
   - Handles corrupt file gracefully
   - Concurrent writes don't corrupt data

2. Use temporary directory for tests
3. Clean up files after each test
4. Run tests to see them FAIL
5. Implement FileSystemNoteRepository
6. All tests must pass at 100%

Use FileManager for operations. Ensure proper error handling.
```

---

#### Step 5: Note Metadata Helpers ✅

**Goal**: Automatic metadata collection (device, timestamp, location)

**What to Build**:
- MetadataCollector service
- Device name detection
- Location services wrapper (permission handling)
- Timestamp generation

**TDD Prompt**:

```
Building on Steps 1-4, create automatic metadata collection.

REQUIREMENTS:
- Create MetadataCollector class with:
  - getCurrentDevice() -> String: Returns device name (e.g., "iPhone 15 Pro")
  - getCurrentLocation() async -> Location?: Returns current location if permitted
  - generateTimestamp() -> Date: Returns current timestamp

- Location struct (from Step 1) with latitude, longitude, accuracy
- Handle location permissions:
  - Request "While Using App" permission
  - Return nil if not granted
  - Don't block if location unavailable

- Device detection should work on iPhone, iPad, Mac (iOS compat mode)

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - getCurrentDevice returns non-empty string
   - Device name format is correct (e.g., "iPhone 15 Pro")
   - generateTimestamp returns recent date
   - getCurrentLocation returns nil when denied
   - getCurrentLocation returns Location when permitted (mock CLLocationManager)
   - Location has valid coordinates
   - Location accuracy is positive number

2. Mock CLLocationManager for tests
3. Run tests to see them FAIL
4. Implement MetadataCollector
5. All tests must pass at 100%

Use CoreLocation framework. Handle all permission states gracefully.
```

---

#### Step 6: Basic Note View Model ✅

**Goal**: Create ViewModel for displaying and editing a single note

**What to Build**:
- NoteViewModel conforming to ObservableObject
- Published properties for all note fields
- Load note from repository
- Save note to repository
- Validation

**TDD Prompt**:

```
Building on Steps 1-5, create the ViewModel for note display/editing.

REQUIREMENTS:
- Create NoteViewModel class:
  - @Published var id: UUID
  - @Published var title: String
  - @Published var content: String
  - @Published var created: Date
  - @Published var device: String
  - @Published var location: Location?
  - @Published var backlinks: [UUID]
  - @Published var isLoading: Bool
  - @Published var error: Error?

- Methods:
  - init(repository: NoteRepository, noteId: UUID)
  - load() async: Load note from repository
  - save() async: Save current state to repository
  - updateContent(_ content: String): Update markdown content
  - updateTitle(_ title: String): Update title

- Validation:
  - Title and content cannot be empty
  - Show error if validation fails

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Initialize with note ID
   - Load populates all fields
   - Load sets isLoading correctly
   - Load handles missing note (sets error)
   - Save updates repository
   - Save validates fields
   - updateContent changes content
   - updateTitle changes title
   - Error handling for repository failures

2. Use InMemoryNoteRepository for tests
3. Run tests to see them FAIL
4. Implement NoteViewModel
5. All tests must pass at 100%

Use @MainActor for UI updates. Follow MVVM pattern.
```

---

#### Step 7: Basic Note List View Model ✅

**Goal**: ViewModel for displaying list of notes

**What to Build**:
- NoteListViewModel with note array
- Load all notes
- Sorting (most recent first)
- Delete note
- Create new note

**TDD Prompt**:

```
Building on Steps 1-6, create the ViewModel for the note list.

REQUIREMENTS:
- Create NoteListViewModel class:
  - @Published var notes: [Note]
  - @Published var isLoading: Bool
  - @Published var error: Error?

- Methods:
  - init(repository: NoteRepository)
  - loadNotes() async: Load all notes from repository
  - createNote(title: String, content: String) async -> Note
  - deleteNote(id: UUID) async
  - refresh() async: Reload notes from repository

- Sorting:
  - Default: most recently created first
  - Use created timestamp

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Initialize with repository
   - loadNotes populates array
   - loadNotes sorts by created date (newest first)
   - createNote adds to list
   - createNote adds metadata automatically
   - deleteNote removes from list
   - refresh updates list
   - isLoading state changes correctly
   - Error handling for repository failures

2. Use InMemoryNoteRepository with sample data
3. Run tests to see them FAIL
4. Implement NoteListViewModel
5. All tests must pass at 100%

Use @MainActor. Inject repository for testability.
```

---

#### Step 8: Basic SwiftUI Views (Read-Only) ✅ COMPLETED

**Goal**: Create minimal UI to display notes (no editing yet)

**What to Build**:
- NoteListView showing all notes
- NoteRowView for each list item
- NoteDetailView showing single note (read-only)
- Navigation between views

**TDD Prompt**:

```
Building on Steps 1-7, create basic read-only UI views.

REQUIREMENTS:
- Create NoteListView:
  - Uses NoteListViewModel
  - Shows list of notes in List/ScrollView
  - Each row shows title + preview (first 100 chars)
  - NavigationStack for drill-down
  - Pull to refresh
  - Loading indicator
  - Error display

- Create NoteRowView:
  - Shows note title (bold)
  - Shows preview text (gray, smaller)
  - Shows created date (relative, e.g., "2 hours ago")

- Create NoteDetailView:
  - Uses NoteViewModel
  - Shows title
  - Shows full markdown content (plain text for now)
  - Shows metadata: device, date, location
  - Read-only (no editing)

TESTING REQUIREMENTS:
1. Write UI tests for:
   - NoteListView displays notes
   - Can tap note to navigate to detail
   - Pull to refresh works
   - NoteDetailView shows correct note
   - Back navigation works
   - Empty state displays when no notes

2. Write snapshot tests for:
   - NoteListView with multiple notes
   - NoteRowView with long/short titles
   - NoteDetailView with complete note

3. Use preview provider with mock data
4. All tests must pass at 100%

Use SwiftUI. Keep it simple and readable. Follow iOS HIG.
```

---

### PHASE 2: NOTE CAPTURE

#### Step 9: Speech Recognition Service ✅ COMPLETED

**Goal**: Integrate Apple Speech framework for transcription

**What to Build**:
- SpeechRecognitionService
- Permission handling
- Real-time transcription
- Silence detection
- Error handling

**TDD Prompt**:

```
We need speech-to-text for capturing notes. Use Apple's Speech framework.

REQUIREMENTS:
- Create SpeechRecognitionService class:
  - requestPermission() async -> Bool
  - startRecording() async throws
  - stopRecording() async -> String
  - var isRecording: Bool { get }
  - var transcriptionPublisher: Published<String>.Publisher

- Features:
  - On-device recognition (offline capable)
  - Real-time transcription updates
  - Auto-stop after silence (configurable timeout, default 3 seconds)
  - Handle all permission states

- Errors:
  - PermissionDeniedError
  - RecognitionFailedError
  - MicrophoneUnavailableError

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - requestPermission returns status
   - startRecording requires permission
   - startRecording sets isRecording = true
   - stopRecording returns transcription
   - stopRecording sets isRecording = false
   - transcriptionPublisher emits updates
   - Silence detection triggers auto-stop
   - Multiple start/stop cycles work correctly
   - Concurrent recordings handled gracefully

2. Mock SFSpeechRecognizer for tests
3. Run tests to see them FAIL
4. Implement SpeechRecognitionService
5. All tests must pass at 100%

Use Speech framework. Handle iOS 17+ requirements. Request microphone permission.
```

---

#### Step 10: Audio Visualization Component ✅ COMPLETED

**Goal**: Show visual feedback during recording (waveform)

**What to Build**:
- WaveformView SwiftUI component
- Audio level monitoring
- Animated visualization
- Color/style theming

**TDD Prompt**:

```
Building on Step 9, create visual feedback for recording.

REQUIREMENTS:
- Create WaveformView SwiftUI view:
  - Input: @Binding<Bool> isRecording
  - Input: @Binding<Float> audioLevel (0.0 to 1.0)
  - Animated waveform bars
  - Smooth transitions
  - Configurable color

- Create AudioLevelMonitor:
  - Monitor microphone input level
  - Publish level updates (0.0 to 1.0)
  - Start/stop monitoring
  - Works with SpeechRecognitionService

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - WaveformView renders when isRecording = true
   - WaveformView hides when isRecording = false
   - Audio level affects visualization
   - AudioLevelMonitor publishes levels
   - AudioLevelMonitor stops cleanly
   - No memory leaks

2. Write snapshot tests for:
   - Waveform at different audio levels
   - Waveform idle state
   - Waveform active state

3. Run tests to see them FAIL
4. Implement WaveformView and AudioLevelMonitor
5. All tests must pass at 100%

Use AVFoundation for audio monitoring. Keep animation smooth (60fps).
```

---

#### Step 11: Capture View Model ✅ COMPLETED

**Goal**: Coordinate speech recognition, metadata collection, and note creation

**What to Build**:
- CaptureViewModel
- Start/stop recording
- Create note from transcription
- Add metadata automatically

**TDD Prompt**:

```
Building on Steps 9-10, create the ViewModel for note capture.

REQUIREMENTS:
- Create CaptureViewModel class:
  - @Published var isRecording: Bool
  - @Published var transcription: String
  - @Published var audioLevel: Float
  - @Published var error: Error?

- Dependencies:
  - SpeechRecognitionService
  - MetadataCollector
  - NoteRepository

- Methods:
  - startRecording() async
  - stopRecording() async -> Note?
  - cancelRecording()
  - saveNote() async -> Note

- Behavior:
  - startRecording: request permissions, start speech recognition, start audio monitoring
  - stopRecording: stop recognition, get transcription, don't save yet
  - saveNote: create Note with transcription + metadata, save to repository

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - startRecording sets isRecording = true
   - startRecording requests permissions
   - transcription updates during recording
   - audioLevel updates during recording
   - stopRecording sets isRecording = false
   - stopRecording returns transcription
   - saveNote creates note with correct fields
   - saveNote adds metadata (device, timestamp, location)
   - cancelRecording discards transcription
   - Error handling for permission denied
   - Error handling for recognition failure

2. Mock all dependencies
3. Run tests to see them FAIL
4. Implement CaptureViewModel
5. All tests must pass at 100%

Use @MainActor. Handle all async operations cleanly.
```

---

#### Step 12: Capture UI View ✅ COMPLETED

**Goal**: Full capture interface with microphone button and waveform

**What to Build**:
- CaptureView
- Large microphone button
- Waveform visualization
- Transcription preview
- Save/cancel actions

**TDD Prompt**:

```
Building on Steps 9-11, create the capture UI.

REQUIREMENTS:
- Create CaptureView:
  - Uses CaptureViewModel
  - Large circular microphone button (center of screen)
  - Tap to start recording, tap again to stop
  - WaveformView shown during recording
  - Transcription text shown after stopping
  - Save button (creates note)
  - Cancel button (discards)
  - Permission prompt if denied
  - Error alerts

- Visual design:
  - Microphone icon changes color when recording (red)
  - Smooth animations
  - Minimal chrome, focused on capture
  - Clear visual feedback

TESTING REQUIREMENTS:
1. Write UI tests for:
   - Tap microphone starts recording
   - Waveform appears during recording
   - Tap microphone again stops recording
   - Transcription appears after stopping
   - Save button creates note
   - Cancel button discards
   - Permission alert shows if denied
   - Error alerts display correctly

2. Write snapshot tests for:
   - Initial state (ready to record)
   - Recording state
   - Stopped state with transcription
   - Permission denied state

3. Run tests to see them FAIL
4. Implement CaptureView
5. All tests must pass at 100%

Use SwiftUI. Follow iOS HIG. Test on iPhone, iPad, Mac.
```

---

#### Step 13: Manual Text Input for Notes ✅ COMPLETED

**Goal**: Allow direct text entry (alternative to speech)

**What to Build**:
- Text editor for manual note creation
- Quick create option
- Metadata still added automatically

**TDD Prompt**:

```
Building on Steps 1-12, add manual text input option.

REQUIREMENTS:
- Update CaptureView with toggle:
  - Switch between speech and text mode
  - Text mode: show TextEditor for content
  - Title field (optional, auto-generated if empty)
  - Save button creates note with metadata

- Create ManualNoteCreator helper:
  - createNote(title: String?, content: String) async -> Note
  - Auto-generate title if empty (use first line or timestamp)
  - Add metadata (device, timestamp, location)

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Switch to text mode hides microphone
   - Text editor accepts input
   - Save with title creates note
   - Save without title auto-generates title
   - Metadata added automatically
   - Empty content prevented (validation)
   - Created note saved to repository

2. Write UI tests for:
   - Toggle between modes works
   - Text input flows correctly
   - Keyboard appears/dismisses
   - Save button enabled when content present

3. Run tests to see them FAIL
4. Implement text input mode
5. All tests must pass at 100%

Keep UI simple. Use TextField for title, TextEditor for content.
```

---

#### Step 14: Auto-Title Generation (iOS NL Framework) ✅ COMPLETED

**Goal**: Generate titles from transcriptions using iOS Natural Language

**What to Build**:
- TitleGenerator service
- Summarization using NLTagger
- Fallback to first line
- Offline operation

**TDD Prompt**:

```
Building on Steps 1-13, add automatic title generation.

REQUIREMENTS:
- Create TitleGenerator class:
  - generateTitle(from content: String) -> String
  - Use iOS Natural Language framework
  - Extract key phrase or summarize to ~5-10 words
  - Fallback: use first line (max 50 chars)
  - Trim and clean result

- Integration:
  - Use in CaptureViewModel after transcription
  - Use in ManualNoteCreator if title empty
  - Allow user to edit generated title

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Generate title from short content
   - Generate title from long content
   - Fallback when summarization fails
   - Fallback for empty content
   - Title length constraints (max 100 chars)
   - Trim whitespace
   - Handle multi-line content

2. Test with various content:
   - Single sentence
   - Multiple paragraphs
   - Code snippets
   - Special characters

3. Run tests to see them FAIL
4. Implement TitleGenerator
5. All tests must pass at 100%

Use NaturalLanguage framework. Keep it simple and fast. Handle failures gracefully.
```

---

### PHASE 3: NOTE DISCOVERY

#### Step 15: Vector Embedding Service ✅ COMPLETED

**Goal**: Generate embeddings for semantic search using Core ML

**What to Build**:
- EmbeddingService
- Load Core ML model
- Generate embeddings for text
- Batch processing
- Caching

**TDD Prompt**:

```
We need vector embeddings for semantic search. Use Core ML on-device models.

REQUIREMENTS:
- Create EmbeddingService class:
  - loadModel() async throws
  - generateEmbedding(for text: String) async throws -> [Float]
  - generateEmbeddings(for texts: [String]) async throws -> [[Float]]
  - var embeddingDimension: Int { get }

- Use sentence transformers model (e.g., all-MiniLM-L6-v2)
- Convert Core ML output to normalized float array
- Cache embeddings in memory (LRU cache, configurable size)
- Background processing (don't block UI)

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - loadModel succeeds
   - generateEmbedding returns correct dimension
   - Same text returns same embedding
   - Similar texts have similar embeddings (cosine similarity)
   - Different texts have different embeddings
   - Batch processing works
   - Caching prevents recomputation
   - Cache eviction works (LRU)
   - Error handling for model load failure

2. Use test embedding model or mock
3. Run tests to see them FAIL
4. Implement EmbeddingService
5. All tests must pass at 100%

Use Core ML. Find or convert a small sentence transformer model. Handle iOS memory constraints.
```

---

#### Step 16: Vector Search Engine ✅ COMPLETED

**Goal**: Implement semantic search using cosine similarity

**What to Build**:
- VectorSearchEngine
- Index notes with embeddings
- Search with relevance threshold
- Rank results

**TDD Prompt**:

```
Building on Step 15, implement vector search.

REQUIREMENTS:
- Create VectorSearchEngine class:
  - indexNote(id: UUID, embedding: [Float]) async
  - search(query: String, threshold: Float = 0.7) async throws -> [SearchResult]
  - removeNote(id: UUID) async
  - rebuild() async

- SearchResult struct:
  - noteId: UUID
  - relevance: Float (cosine similarity, 0.0 to 1.0)

- Dependencies:
  - EmbeddingService

- Algorithm:
  - Generate embedding for query
  - Compute cosine similarity with all indexed notes
  - Filter by threshold
  - Sort by relevance (highest first)

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Index note stores embedding
   - Search finds relevant notes
   - Search filters by threshold
   - Results sorted by relevance
   - Remove note works
   - Rebuild reindexes all notes
   - Empty index returns no results
   - Similar queries return similar results
   - Performance with 1000+ notes

2. Mock EmbeddingService
3. Run tests to see them FAIL
4. Implement VectorSearchEngine
5. All tests must pass at 100%

Use efficient similarity computation. Consider vDSP for optimization. Handle edge cases.
```

---

#### Step 17: Background Embedding Generation ✅ COMPLETED

**Goal**: Generate embeddings for all notes in background

**What to Build**:
- EmbeddingBackgroundService
- Queue new notes for processing
- Batch processing
- Progress tracking
- Persistence of embeddings

**TDD Prompt**:

```
Building on Steps 15-16, add background embedding generation.

REQUIREMENTS:
- Create EmbeddingBackgroundService class:
  - start() async: Begin background processing
  - stop() async: Pause processing
  - queueNote(id: UUID) async: Add note to processing queue
  - var progress: Published<Float>.Publisher: Progress (0.0 to 1.0)
  - var isProcessing: Bool { get }

- Behavior:
  - Process notes in queue (FIFO)
  - Batch size: configurable (default 10)
  - Low priority thread
  - Persist embeddings to disk (JSON or binary)
  - Load existing embeddings on startup
  - Skip already processed notes

- Integration:
  - Queue note after creation/update
  - Feed embeddings to VectorSearchEngine

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Start begins processing
   - Stop pauses processing
   - Queue adds notes
   - Notes processed in order
   - Progress updates correctly
   - Embeddings persisted
   - Embeddings loaded on startup
   - Skip already processed notes
   - Handle errors gracefully (retry)

2. Mock EmbeddingService with delays
3. Run tests to see them FAIL
4. Implement EmbeddingBackgroundService
5. All tests must pass at 100%

Use Task with low priority. Persist embeddings separately from notes.
```

---

#### Step 18: Search View Model ✅ COMPLETED

**Goal**: ViewModel for search interface

**What to Build**:
- SearchViewModel
- Query input handling
- Result ranking
- Filter integration

**TDD Prompt**:

```
Building on Steps 15-17, create the search ViewModel.

REQUIREMENTS:
- Create SearchViewModel class:
  - @Published var query: String
  - @Published var results: [SearchResult]
  - @Published var isSearching: Bool
  - @Published var threshold: Float (configurable, default 0.7)

- Dependencies:
  - VectorSearchEngine
  - NoteRepository

- Methods:
  - search() async
  - clear()
  - loadNoteDetails(for results: [SearchResult]) async -> [Note]

- Behavior:
  - Debounce query input (500ms)
  - Search when query changes
  - Clear results when query empty
  - Load full note details for results

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - query changes trigger search
   - Debouncing prevents excessive searches
   - Empty query clears results
   - Results sorted by relevance
   - Threshold filtering works
   - loadNoteDetails fetches correct notes
   - isSearching state correct
   - Handle errors gracefully

2. Mock dependencies
3. Run tests to see them FAIL
4. Implement SearchViewModel
5. All tests must pass at 100%

Use Combine for debouncing. Use @MainActor.
```

---

#### Step 19: Enhanced Note List with Search ✅ COMPLETED

**Goal**: Add search bubble and filtering to note list

**What to Build**:
- SearchBar component
- Integrate SearchViewModel
- Switch between default and search modes
- Clear search

**TDD Prompt**:

```
Building on Steps 7-8 and 18, enhance NoteListView with search.

REQUIREMENTS:
- Update NoteListView:
  - Search bar at top (SearchBar component)
  - Switch between modes:
    - Default: show all notes, sorted by recent
    - Search: show search results, sorted by relevance
  - Clear button in search bar
  - Loading indicator during search
  - Empty state for no results

- Create SearchBar SwiftUI component:
  - Text field with search icon
  - Clear button (X)
  - Binding to query string
  - Keyboard dismiss on scroll

TESTING REQUIREMENTS:
1. Write UI tests for:
   - Search bar appears
   - Type query triggers search
   - Results displayed correctly
   - Clear button works
   - Switch back to default mode
   - Empty state shown when no results
   - Loading indicator during search

2. Write snapshot tests for:
   - Default mode
   - Search mode with results
   - Empty search results
   - Search bar focused

3. Run tests to see them FAIL
4. Implement enhanced NoteListView
5. All tests must pass at 100%

Use SwiftUI. Keep transitions smooth. Follow iOS patterns.
```

---

#### Step 20: Note Preview/Abstract Generation ✅ COMPLETED

**Goal**: Generate short previews for note list display

**What to Build**:
- AbstractGenerator service
- Summarize to ~100 chars
- Fallback to first N chars
- Strip markdown syntax

**TDD Prompt**:

```
Building on previous steps, add note preview generation.

REQUIREMENTS:
- Create AbstractGenerator class:
  - generateAbstract(from content: String, maxLength: Int = 100) -> String
  - Use iOS Natural Language for summarization
  - Fallback: first N chars with smart truncation (word boundary)
  - Strip markdown syntax (headers, links, etc.)
  - Add ellipsis if truncated

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Generate abstract from short content
   - Generate abstract from long content
   - Strip markdown headers
   - Strip markdown links
   - Strip markdown formatting
   - Truncate at word boundary
   - Add ellipsis when truncated
   - Handle empty content
   - Handle content with only markdown

2. Test with various content types
3. Run tests to see them FAIL
4. Implement AbstractGenerator
5. All tests must pass at 100%

Use NaturalLanguage framework. Keep it simple. Handle edge cases.
```

---

### PHASE 4: GIT INTEGRATION

#### Step 21: Git Repository Service

**Goal**: Integrate libgit2 for git operations

**What to Build**:
- GitService wrapper around libgit2
- Initialize repository
- Commit operations
- Status checking
- Basic config

**TDD Prompt**:

```
We need git integration for syncing notes. Use libgit2 (via Swift wrapper like SwiftGit2).

REQUIREMENTS:
- Create GitService class:
  - initRepository(at path: String) throws
  - commit(message: String, files: [String]) throws -> String (commit hash)
  - status() throws -> GitStatus
  - config(name: String, email: String) throws
  - var currentBranch: String { get }

- GitStatus struct:
  - modifiedFiles: [String]
  - untrackedFiles: [String]
  - stagedFiles: [String]
  - isClean: Bool

- Behavior:
  - Create .git directory if doesn't exist
  - Auto-stage specified files before commit
  - Descriptive commit messages per note

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - initRepository creates .git
   - commit creates commit object
   - commit returns hash
   - status detects modified files
   - status detects untracked files
   - config sets user info
   - currentBranch returns correct branch
   - Handle errors (no repo, conflicts, etc.)

2. Use temporary directory for tests
3. Clean up after each test
4. Run tests to see them FAIL
5. Implement GitService
6. All tests must pass at 100%

Use SwiftGit2 or ObjectiveGit. Handle all git errors gracefully.
```

---

#### Step 22: SSH Key Management

**Goal**: Generate and manage SSH keys for git authentication

**What to Build**:
- SSHKeyManager
- Generate key pairs
- Store in iOS Keychain
- Export public key
- Load keys for git

**TDD Prompt**:

```
Building on Step 21, add SSH key management.

REQUIREMENTS:
- Create SSHKeyManager class:
  - generateKeyPair() throws -> SSHKeyPair
  - saveKeyPair(_ keyPair: SSHKeyPair) throws
  - loadKeyPair() throws -> SSHKeyPair?
  - deleteKeyPair() throws
  - exportPublicKey() throws -> String

- SSHKeyPair struct:
  - publicKey: String
  - privateKey: Data (encrypted)

- Behavior:
  - Generate RSA 4096-bit keys (or Ed25519)
  - Store private key in iOS Keychain (encrypted)
  - Public key as OpenSSH format
  - Handle key rotation

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - generateKeyPair creates valid keys
   - saveKeyPair stores in keychain
   - loadKeyPair retrieves from keychain
   - deleteKeyPair removes from keychain
   - exportPublicKey returns OpenSSH format
   - Public/private key match
   - Multiple save/load cycles work
   - Handle missing keys gracefully

2. Mock Keychain in tests
3. Run tests to see them FAIL
4. Implement SSHKeyManager
5. All tests must pass at 100%

Use Security framework for Keychain. Use CryptoKit or OpenSSL for key generation.
```

---

#### Step 23: Git Remote Operations

**Goal**: Push, pull, and fetch over SSH

**What to Build**:
- Extend GitService with remote operations
- SSH authentication integration
- Push/pull/fetch
- Conflict detection

**TDD Prompt**:

```
Building on Steps 21-22, add remote git operations.

REQUIREMENTS:
- Extend GitService with:
  - addRemote(name: String, url: String) throws
  - push(remote: String = "origin", branch: String = "main") async throws
  - pull(remote: String = "origin", branch: String = "main") async throws -> PullResult
  - fetch(remote: String = "origin") async throws

- PullResult enum:
  - success
  - conflicts([String]) (list of conflicting files)

- Dependencies:
  - SSHKeyManager for authentication

- Behavior:
  - Use SSH keys from keychain
  - Background thread for network operations
  - Retry on transient failures (3 attempts)
  - Timeout after 30 seconds

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - addRemote succeeds
   - push sends commits
   - pull fetches commits
   - pull detects conflicts
   - fetch retrieves refs
   - SSH authentication works
   - Network error handling
   - Timeout handling
   - Retry logic

2. Mock git remote (use test repo)
3. Run tests to see them FAIL
4. Implement remote operations
5. All tests must pass at 100%

Use libgit2 remote callbacks for SSH. Handle all network errors. Test with real git server if possible.
```

---

#### Step 24: Three-Way Merge Handler

**Goal**: Implement conflict resolution for note files

**What to Build**:
- MergeService
- Three-way merge algorithm
- CRDT-aware merging
- Conflict resolution UI

**TDD Prompt**:

```
Building on Steps 21-23, implement merge conflict resolution.

REQUIREMENTS:
- Create MergeService class:
  - merge(base: String, ours: String, theirs: String) throws -> MergeResult
  - resolveConflict(noteId: UUID, resolution: Resolution) async throws

- MergeResult enum:
  - success(merged: String)
  - conflict(ConflictInfo)

- ConflictInfo struct:
  - noteId: UUID
  - base: String (common ancestor)
  - ours: String (local version)
  - theirs: String (remote version)

- Resolution enum:
  - keepOurs
  - keepTheirs
  - manual(content: String)

- Algorithm:
  - Parse YAML frontmatter
  - Merge metadata fields (union for backlinks)
  - Use CRDT timestamps for conflict resolution
  - Merge content (line-based diff)

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Merge with no conflicts
   - Merge with metadata conflicts
   - Merge with content conflicts
   - Backlinks merged correctly (union)
   - Timestamp determines winner
   - Manual resolution works
   - Handle malformed files

2. Test various conflict scenarios
3. Run tests to see them FAIL
4. Implement MergeService
5. All tests must pass at 100%

Use diff algorithm (Myers diff). Respect CRDT semantics. Keep it deterministic.
```

---

#### Step 25: Automatic Git Sync Service

**Goal**: Auto-commit after changes, background push

**What to Build**:
- GitSyncService
- Watch for note changes
- Auto-commit locally
- Background push (opportunistic)
- Descriptive commit messages

**TDD Prompt**:

```
Building on Steps 21-24, implement automatic git sync.

REQUIREMENTS:
- Create GitSyncService class:
  - start() async: Begin watching for changes
  - stop() async: Stop watching
  - syncNow() async: Immediate sync
  - var lastSyncTime: Date? { get }
  - var isSyncing: Bool { get }

- Dependencies:
  - GitService
  - NoteRepository
  - MergeService

- Behavior:
  - Watch NoteRepository for changes
  - Auto-commit locally after each change
  - Commit message: "Add note: [title]", "Update note: [title]", "Delete note: [title]"
  - Background push every 5 minutes (configurable)
  - Low priority thread for push
  - Pull before push
  - Handle merge conflicts

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - start begins watching
   - Note creation triggers commit
   - Note update triggers commit
   - Note deletion triggers commit
   - Commit messages correct format
   - Background push scheduled
   - Pull before push
   - Merge conflicts handled
   - Multiple rapid changes batched
   - Stop cancels operations

2. Mock dependencies
3. Run tests to see them FAIL
4. Implement GitSyncService
5. All tests must pass at 100%

Use NotificationCenter or Combine for change notifications. Use Timer for periodic push.
```

---

#### Step 26: Git Setup UI

**Goal**: Onboarding flow for git repository setup

**What to Build**:
- GitSetupView
- Repository URL input
- SSH key display/copy
- Connection test
- Guided setup

**TDD Prompt**:

```
Building on Steps 21-25, create git setup UI.

REQUIREMENTS:
- Create GitSetupView:
  - Step 1: Generate SSH key
  - Step 2: Display public key (with copy button)
  - Step 3: Enter git repository URL
  - Step 4: Test connection
  - Step 5: Initialize sync

- Auto-create repository if URL doesn't exist (future: GitHub API)
- Guided instructions for adding key to GitHub/GitLab
- Test connection before proceeding
- Show error messages clearly
- Skip option (setup later)

TESTING REQUIREMENTS:
1. Write UI tests for:
   - Navigate through all steps
   - SSH key generated
   - Public key copyable
   - Repository URL validation
   - Connection test works
   - Success leads to main app
   - Error messages display
   - Skip option works

2. Write snapshot tests for each step
3. Run tests to see them FAIL
4. Implement GitSetupView
5. All tests must pass at 100%

Use SwiftUI. Make it clear and simple. Assume user has basic git knowledge.
```

---

### PHASE 5: CRDT SYNC

#### Step 27: CRDT Integration (Automerge) ✅ COMPLETED

**Goal**: Integrate Automerge for conflict-free sync

**What to Build**:
- Automerge wrapper
- Note document type
- CRDT operations
- State synchronization

**TDD Prompt**:

```
We need CRDT for conflict-free sync across devices. Use Automerge (Swift wrapper).

REQUIREMENTS:
- Create CRDTService class:
  - createDocument() -> DocHandle
  - updateNote(docHandle: DocHandle, note: Note) throws
  - readNote(docHandle: DocHandle) throws -> Note
  - merge(doc1: DocHandle, doc2: DocHandle) -> DocHandle
  - save(docHandle: DocHandle) -> Data
  - load(data: Data) -> DocHandle

- Note schema in Automerge:
  - id: String
  - created: Int64 (timestamp)
  - device: String
  - location: Map (lat, lng, accuracy)
  - content: String
  - title: String
  - backlinks: List<String>

- Behavior:
  - Automatic conflict resolution
  - Last-write-wins for scalar fields
  - Union for backlinks array
  - Preserve all metadata

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Create document
   - Update note in document
   - Read note from document
   - Merge two documents
   - Concurrent updates merge correctly
   - Backlinks merged (union)
   - Save/load round trip
   - Large documents perform well

2. Run tests to see them FAIL
3. Implement CRDTService
4. All tests must pass at 100%

Use automerge-swift. Map Note model to CRDT document. Handle all edge cases.
```

---

#### Step 28: CRDT Repository Implementation

**Goal**: Replace FileSystemNoteRepository with CRDT-backed version

**What to Build**:
- CRDTNoteRepository implementing NoteRepository
- Store each note as CRDT document
- Sync with file system
- Bidirectional updates

**TDD Prompt**:

```
Building on Step 27, create CRDT-backed repository.

REQUIREMENTS:
- Create CRDTNoteRepository implementing NoteRepository:
  - Store notes in Automerge documents
  - Persist to SQLite (one row per note)
  - Sync with file system (export to markdown files)
  - Watch file system for external changes
  - Merge external changes into CRDT

- Schema:
  - notes table: id (UUID), crdt_data (BLOB), file_path (TEXT), last_modified (INT)

- Behavior:
  - All updates go through CRDT
  - Export to markdown after each update
  - Import from markdown on file system changes
  - Detect conflicts and merge

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Create note via CRDT
   - Note exported to file
   - Read note from CRDT
   - Update note via CRDT
   - File updated on disk
   - External file change imported
   - Concurrent updates merge
   - Delete removes CRDT doc and file
   - List queries CRDT store
   - Migration from FileSystemNoteRepository

2. Use temporary directory and database
3. Run tests to see them FAIL
4. Implement CRDTNoteRepository
5. All tests must pass at 100%

Use SQLite for CRDT storage. Use FileManager watcher for external changes.
```

---

#### Step 29: iCloud Sync Service

**Goal**: Sync CRDT database across devices via iCloud

**What to Build**:
- iCloudSyncService
- CloudKit integration
- Sync CRDT changes
- Merge remote changes

**TDD Prompt**:

```
Building on Steps 27-28, add iCloud sync for CRDT database.

REQUIREMENTS:
- Create iCloudSyncService class:
  - start() async: Begin iCloud sync
  - stop() async: Stop sync
  - syncNow() async: Force immediate sync
  - var isSyncing: Bool { get }

- Use CloudKit:
  - Store CRDT document data per note
  - Record type: "Note" with fields: id, crdt_data, modified
  - Subscribe to remote changes
  - Merge remote documents with local

- Behavior:
  - Sync on app launch
  - Sync on change
  - Background sync every 10 minutes
  - Handle conflicts via CRDT merge
  - Show sync status

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - start begins syncing
   - Local change syncs to iCloud
   - Remote change syncs to local
   - Concurrent changes merge
   - Sync status updates
   - Handle network failures
   - Retry on error
   - Stop cancels operations

2. Mock CloudKit
3. Run tests to see them FAIL
4. Implement iCloudSyncService
5. All tests must pass at 100%

Use CloudKit. Handle all error cases. Respect battery and network constraints.
```

---

#### Step 30: Sync Coordinator

**Goal**: Coordinate git and iCloud sync

**What to Build**:
- SyncCoordinator
- Manage both sync services
- Priority: CRDT -> git
- Status reporting

**TDD Prompt**:

```
Building on Steps 25 and 29, coordinate both sync mechanisms.

REQUIREMENTS:
- Create SyncCoordinator class:
  - start() async: Start both sync services
  - stop() async: Stop both
  - syncAll() async: Force full sync
  - var syncStatus: Published<SyncStatus>.Publisher

- SyncStatus struct:
  - iCloudStatus: SyncState (idle, syncing, error)
  - gitStatus: SyncState (idle, syncing, error)
  - lastSyncTime: Date?

- Dependencies:
  - iCloudSyncService
  - GitSyncService

- Behavior:
  - iCloud sync has priority (CRDT is source of truth)
  - Git sync exports from CRDT
  - Changes from git imported to CRDT
  - Coordinated error handling

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Start both services
   - Stop both services
   - CRDT change triggers both syncs
   - Git import updates CRDT
   - Status updates correctly
   - Error in one doesn't block other
   - Full sync completes both

2. Mock both sync services
3. Run tests to see them FAIL
4. Implement SyncCoordinator
5. All tests must pass at 100%

Coordinate carefully. Keep CRDT as source of truth. Handle failures independently.
```

---

### PHASE 6: POLISH & SECURITY

#### Step 31: Biometric Authentication

**Goal**: Add Face ID/Touch ID unlock

**What to Build**:
- BiometricAuthService
- Lock/unlock app
- Settings toggle
- Fallback passcode

**TDD Prompt**:

```
Add biometric authentication to secure the app.

REQUIREMENTS:
- Create BiometricAuthService class:
  - isBiometricAvailable() -> Bool
  - authenticate(reason: String) async -> Bool
  - var biometricType: BiometricType { get } (faceID, touchID, none)

- BiometricType enum:
  - faceID
  - touchID
  - none

- Integration:
  - Lock app on background
  - Require auth on foreground
  - Settings toggle to enable/disable
  - Fallback to passcode if biometric fails

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - isBiometricAvailable detects capability
   - authenticate returns success/failure
   - biometricType correct for device
   - Lock on background
   - Unlock on foreground
   - Settings toggle works
   - Fallback to passcode

2. Mock LAContext
3. Run tests to see them FAIL
4. Implement BiometricAuthService
5. All tests must pass at 100%

Use LocalAuthentication framework. Handle all error cases gracefully.
```

---

#### Step 32: Encryption at Rest

**Goal**: Encrypt local CRDT database

**What to Build**:
- EncryptionService
- Encrypt/decrypt SQLite
- Key management
- Transparent to app

**TDD Prompt**:

```
Encrypt the local CRDT database at rest.

REQUIREMENTS:
- Create EncryptionService class:
  - encrypt(data: Data, key: SymmetricKey) throws -> Data
  - decrypt(data: Data, key: SymmetricKey) throws -> Data
  - generateKey() -> SymmetricKey
  - storeKey(key: SymmetricKey) throws
  - loadKey() throws -> SymmetricKey?

- Use CryptoKit:
  - AES-256-GCM encryption
  - Store key in iOS Keychain
  - Protect with biometric requirement

- Integration:
  - Encrypt SQLite database file
  - Decrypt on app launch
  - Transparent to CRDTNoteRepository

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Generate key
   - Store key in keychain
   - Load key from keychain
   - Encrypt data
   - Decrypt data
   - Round-trip (encrypt -> decrypt)
   - Wrong key fails decrypt
   - Handle missing key

2. Mock Keychain
3. Run tests to see them FAIL
4. Implement EncryptionService
5. All tests must pass at 100%

Use CryptoKit. Use SQLCipher for SQLite encryption. Handle key rotation.
```

---

#### Step 33: Trash and Deletion

**Goal**: Implement trash with auto-purge

**What to Build**:
- Trash management
- Soft delete notes
- Auto-purge after period
- Restore functionality

**TDD Prompt**:

```
Implement trash for deleted notes.

REQUIREMENTS:
- Update Note model:
  - Add `deletedAt: Date?` field
  - `isDeleted` computed property

- Update NoteRepository:
  - delete(id:) sets deletedAt instead of hard delete
  - restore(id:) clears deletedAt
  - purge(id:) hard deletes
  - listTrashed() returns deleted notes

- Create TrashService:
  - autoPurgeAfter: TimeInterval (configurable, default 30 days)
  - schedulePurge()
  - purgeOld() async

- UI:
  - Trash view showing deleted notes
  - Restore button
  - Permanent delete button
  - Auto-purge indicator

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - Soft delete sets deletedAt
   - Deleted notes not in main list
   - listTrashed returns deleted notes
   - Restore clears deletedAt
   - Purge hard deletes
   - Auto-purge removes old notes
   - Backlinks to deleted notes remain
   - Git sync handles soft deletes

2. Run tests to see them FAIL
3. Implement trash system
4. All tests must pass at 100%

Update CRDT schema. Handle git sync. Make purge configurable in settings.
```

---

#### Step 34: Error Handling and Logging

**Goal**: Comprehensive error handling and user-friendly messages

**What to Build**:
- Error presentation system
- Logging service
- Error recovery
- User guidance

**TDD Prompt**:

```
Improve error handling across the app.

REQUIREMENTS:
- Create ErrorPresenter class:
  - present(error: Error, in view: some View)
  - Categorize errors (network, permission, data, git, sync)
  - User-friendly messages
  - Suggested actions

- Enhanced Logger:
  - Categories: general, database, network, git, sync, ui
  - Levels: debug, info, warning, error, critical
  - Write to file (for debugging)
  - Privacy-safe (no sensitive data)

- Error types:
  - RecoverableError (with retry action)
  - FatalError (with restart action)
  - WarningError (dismissible)

TESTING REQUIREMENTS:
1. Write tests FIRST for:
   - ErrorPresenter shows correct message
   - Suggested actions provided
   - Logger writes to file
   - Log rotation works
   - Privacy respected (no passwords logged)
   - Error categories correct
   - Retry actions work

2. Run tests to see them FAIL
3. Implement error handling
4. All tests must pass at 100%

Use SwiftUI alerts. Make messages helpful. Provide actionable guidance.
```

---

#### Step 35: Settings and Configuration

**Goal**: Comprehensive settings screen

**What to Build**:
- SettingsView
- All configurable options
- Git management
- About/help

**TDD Prompt**:

```
Create comprehensive settings screen.

REQUIREMENTS:
- Create SettingsView with sections:

  **Git Configuration**:
  - Repository URL
  - View/copy public SSH key
  - Test connection
  - Manual sync
  - Last sync time

  **Search Settings**:
  - Vector search threshold slider (0.5 - 0.9)
  - Embedding generation toggle
  - Reindex all notes

  **Privacy & Security**:
  - Biometric unlock toggle
  - Location permission toggle
  - View encryption status

  **Trash**:
  - Auto-purge duration (7, 14, 30, 60 days)
  - Manual purge now

  **About**:
  - App version
  - Open source license
  - GitHub repository link
  - Help/documentation

TESTING REQUIREMENTS:
1. Write UI tests for:
   - Navigate to settings
   - Toggle all switches
   - Sliders adjust values
   - Test connection works
   - Manual sync works
   - Help links open

2. Write snapshot tests for:
   - Settings screen
   - Each section

3. Run tests to see them FAIL
4. Implement SettingsView
5. All tests must pass at 100%

Use SwiftUI Form. Persist settings in UserDefaults. Make it clear and organized.
```

---

## Final Integration Step

### Step 36: End-to-End Integration

**Goal**: Wire all components together and test complete workflows

**What to Build**:
- Complete app flow
- Integration tests
- Performance testing
- Bug fixes

**TDD Prompt**:

```
Final integration of all components.

REQUIREMENTS:
- Wire all services in App startup:
  - Initialize repositories
  - Start sync services
  - Load settings
  - Setup error handling

- Complete workflows:
  1. First-time setup -> git config -> capture note -> sync
  2. Capture note -> auto-title -> sync -> search -> find note
  3. Edit note -> save -> sync -> verify on disk
  4. External edit -> detect -> merge -> update UI
  5. Delete note -> trash -> restore -> verify
  6. Background sync -> merge conflict -> resolve

- Integration points:
  - All ViewModels use correct repositories
  - All services started/stopped properly
  - Error handling connected
  - Logging active

TESTING REQUIREMENTS:
1. Write integration tests for:
   - Complete capture workflow
   - Complete search workflow
   - Complete sync workflow
   - Complete git workflow
   - Complete merge workflow
   - Complete trash workflow

2. Write UI tests for:
   - First-time user experience
   - Daily usage patterns
   - Error scenarios
   - Offline scenarios

3. Performance tests:
   - Search with 1000 notes
   - Sync with 1000 notes
   - UI responsiveness
   - Memory usage
   - Battery impact

4. All tests must pass at 100%

Test on iPhone, iPad, and Mac. Fix all bugs. Ensure smooth experience.
```

---

## Post-MVP: Claude Integration (Future Phases)

### Step 37-42: Claude API Integration
(To be detailed later - includes conversation interface, RAG, auto-edits, episodic memory)

### Step 43-46: Advanced Features
(To be detailed later - includes link autocomplete, backlinks display, duplicate detection)

---

## Summary

This plan provides **36 core steps** to build the MVP Zettelkasten app, organized into 6 phases:

1. **Foundation** (Steps 1-8): Core data models and basic UI
2. **Note Capture** (Steps 9-14): Speech and text input
3. **Note Discovery** (Steps 15-20): Vector search and UI
4. **Git Integration** (Steps 21-26): Full git sync with SSH
5. **CRDT Sync** (Steps 27-30): iCloud sync and coordination
6. **Polish & Security** (Steps 31-35): Security and finishing touches

Each step:
- Builds on previous steps (no orphaned code)
- Starts with tests (TDD)
- Has clear requirements
- Includes comprehensive testing
- Integrates fully before moving on

The plan emphasizes:
- Small, safe increments
- Strong testing at every stage
- No big jumps in complexity
- Early and continuous integration
- Correctness over performance

---

## Usage Instructions

1. Execute steps in order (don't skip)
2. Ensure 100% test pass rate before moving to next step
3. Commit after each step completion
4. Review and refactor between phases
5. Adjust step scope if implementation proves too large
6. Add sub-steps if needed for particularly complex steps

## Notes for LLM Implementation

- Each prompt is designed to be self-contained
- Tests must be written FIRST (TDD)
- All tests must pass before proceeding
- Use Swift best practices
- Target iOS 17+
- Support iPhone, iPad, Mac (iOS compatibility)
- Prioritize correctness over cleverness
- Keep code maintainable and readable
