# Zettelkasten iOS App - Technical Specification

## Overview

An iOS application for managing a git-based Zettelkasten/Commonplace Book system with speech input, AI assistance via Claude API, and vector search capabilities. The app runs on iPhone, iPad, and Mac (via iOS compatibility) and serves as a "second brain" for capturing thoughts, retrieving knowledge, and conversational learning.

## Core Philosophy

The app is designed around two primary use cases:
1. **Capture**: Quick, reliable note creation via speech throughout the day
2. **Retrieval**: Finding and exploring existing notes through vector search

A secondary use case is conversational exploration with Claude for learning and idea development.

---

## Architecture

### Data Model & Source of Truth

**Key Principle**: The CRDT database is the source of truth, not git.

- **CRDT Database**: Primary data store containing all notes, metadata, and conversation history
- **Git Repository**: Treated as "just another client" in the synchronization model
  - Acts as a view/export/backup mechanism
  - Enables manual access via external editors (vim, etc.)
  - Bidirectional: changes in git sync back to database like any offline client

### Synchronization Strategy

- **iCloud Sync**: CRDT database syncs across devices via iCloud
- **Git Sync**:
  - Auto-commit locally after changes
  - Opportunistic background push (low priority thread, not event-triggered)
  - Three-way merge for conflict resolution
  - Descriptive per-note commit messages: "Add note: [title]", "Update note: [title]", "Delete note: [title]"
- **Offline-First**: Full functionality except Claude conversations
- **Invisible Sync**: All synchronization happens automatically in background

### File Format

```yaml
---
id: 01234567-89ab-cdef-0123-456789abcdef
created: 2025-11-05T10:30:00Z
device: iPhone 15 Pro
location:
  latitude: 37.7749
  longitude: -122.4194
  accuracy: 5.0
backlinks:
  - 01234567-89ab-cdef-0123-456789abcdef
  - 98765432-10fe-dcba-9876-543210fedcba
---

# Note Title

Note content in extended markdown with footnote support[^1].

[^1]: Footnote text here.
```

**Format Details**:
- Markdown files with YAML frontmatter
- Extended markdown support (footnotes, etc.)
- v7 UUIDs for filenames (timestamp-based)
- Standard markdown hyperlinks for connections
- Folder structure may exist, but conceptually a flat node graph

---

## Features

### MVP Features (First Release)

#### 1. Note Capture

**Quick Voice Capture**:
- Tap microphone button to start recording
- Visual waveform indicator during recording
- Auto-timeout after silence detection
- Uses Apple's Speech framework (free, on-device, offline-capable)
- Immediately transcribes and saves as new note
- Works completely offline

**Manual Text Creation**:
- Standard text input for creating notes
- Raw markdown editor with syntax visible
- Extended markdown support (footnotes, etc.)

**Automatic Metadata**:
- Timestamp (creation date/time)
- Location (granular, "While Using App" permission)
- Device name (e.g., "iPhone 15 Pro", "iPad Air", "Mac")
- Note title (iOS summarization model or first line fallback)
- Unique v7 UUID identifier

#### 2. Note Editing

- Raw markdown text editor
- Extended markdown with footnotes
- Clickable links to navigate between notes
- Minimal interface - no word count, preview, etc.
- Speech input for editing (via Claude post-MVP)

#### 3. Search & Discovery

**Vector Search**:
- Local on-device embeddings via Core ML
- Background batch processing for embedding generation
- Whole note or section-level granularity
- Dynamic relevance threshold
- Works completely offline

**Note List View**:
- Infinite scroll
- Search bubble at top
- Default sort: most recently accessed/edited
- Search mode: filters list and sorts by relevance
- Each note displays: title + preview (auto-generated abstract)

#### 4. Git Integration

**Authentication**:
- SSH key-based authentication
- Support any git host (GitHub, GitLab, private servers, etc.)
- App generates SSH key pair
- User adds public key to git host

**Sync Behavior**:
- Auto-commit locally after changes
- Opportunistic background push (low priority)
- Three-way merge for conflicts
- Bidirectional: git edits sync back to database
- Descriptive commit messages per note

**MVP Setup**:
- Auto-create new repository
- Auto-generate SSH keys
- Guide user to add public key to git host
- Test connection before proceeding

#### 5. Deletion & Trash

- Notes moved to trash (not hard deleted)
- Trash auto-purges after configurable period
- Links to trashed notes remain functional until purge
- Can undelete from trash

#### 6. Security

- Biometric unlock (Face ID/Touch ID)
- Encryption at rest for local database
- SSH keys stored in iOS keychain
- Standard iOS accessibility features

#### 7. Platform Support

**iPhone**:
- Single column layout
- One view at a time
- Optimized for focused interaction

**iPad & Mac**:
- Side-by-side layout: note list | note editor
- Larger screen real estate utilization
- Mac via iOS compatibility mode (not native)

#### 8. First-Time Experience

- Auto-create git repository and SSH keys
- Guided setup for adding public key to git host
- Open directly to capture interface (mic ready)
- No required configuration to start capturing

### Post-MVP Features

#### 1. Claude Integration

**API Configuration**:
- User provides own Claude API key
- Stored securely in iOS keychain
- Configurable system prompt
- Model selection:
  - Claude 3.5 Sonnet (4.5) for conversations
  - Claude 3 Haiku for quick tasks (titles, edits)

**Conversation Mode**:
- Text input field + microphone button
- Speech → Apple transcription → Claude
- Requires internet connection
- Bottom panel/sheet interface (keeps note visible)
- Claude cites sources from Zettelkasten naturally
- Claude retrieves related notes via RAG (dynamic relevance)
- Acts as research assistant/TA

**Conversation History**:
- Saved in CRDT database
- Synced across devices via iCloud
- NOT exported to git repository
- Linked to notes but stored separately
- Episodic memory pattern (inspired by Obra's plugin)

**AI-Assisted Editing**:
- Voice commands to Claude describing desired changes
- Auto-apply edits with quick revert option
- Claude searches and inserts links
- Conversational disambiguation ("Did you mean note X1, X2, or X3?")

#### 2. Link Autocomplete

- Type `[` to trigger autocomplete dropdown
- Filtered by note title as you type
- Select from list to insert markdown link
- Manual power-user feature

#### 3. Backlinks

- Auto-generated in note metadata
- When Note A links to Note B, B's backlinks updated
- Display backlinks section in note view
- Enables connection discovery

#### 4. Duplicate Detection

**Behavior**:
- Check for similar notes on all creation (voice and manual)
- Save immediately anyway (no blocking)
- Flag for review in background

**Review Queue**:
- Dedicated "Review duplicates" section
- No push notifications
- Side-by-side comparison UI
- Options: merge, dismiss, link notes

#### 5. Auto-Generated Titles & Abstracts

- iOS Natural Language framework for summarization
- Generate title from transcription/content
- Generate abstract for note previews
- Fallback to first line if summarization unavailable
- Works offline

#### 6. Markdown Import

- Import existing markdown files
- Create new notes with v7 UUIDs
- Preserve existing frontmatter if present
- Auto-generate or leave empty missing metadata
- Preview/confirmation before import
- Standalone feature (not buried in settings)

#### 7. Advanced Git Features

- Clone existing repositories
- Manual SSH key management
- Custom git configuration
- Support for existing Zettelkasten repos

---

## User Interface

### Navigation & Layout

**Claude-Style Interface**:
- Conversation-first design
- Sidebar for navigation/history
- Clean and minimal aesthetic

**Platform-Specific Layouts**:

*iPhone*:
- Single column
- One thing at a time
- Bottom sheet for Claude (post-MVP)

*iPad/Mac*:
- Side-by-side: note list | note editor
- Bottom panel for Claude (post-MVP)
- Keyboard shortcuts (Mac)

### Screens & Views

#### Main View (Note List)
- Infinite scroll of notes
- Search bubble at top
- Each item: title + preview
- Sort: most recent by default, relevance when searching
- Tap note to open editor

#### Note Editor
- Full-screen or right panel (iPad/Mac)
- Raw markdown editing
- Clickable links for navigation
- Microphone button for voice input
- "Ask Claude" button (post-MVP)

#### Claude Conversation Panel (Post-MVP)
- Bottom panel/sheet on all platforms
- Text input + microphone button
- Keeps note visible above
- Shows Claude's responses with cited sources
- Related notes surfaced contextually

#### Capture Interface
- Default first-time view
- Large microphone button
- Waveform visualization during recording
- Quick text input option
- Minimal chrome, focused on capture

#### Review Queue (Post-MVP)
- List of potential duplicate pairs
- Side-by-side comparison
- Actions: merge, dismiss, link
- Badge/indicator showing pending reviews

#### Trash
- List of deleted notes
- Restore or permanently delete
- Auto-purge indicator
- Search/filter capabilities

### Settings & Preferences

**MVP Settings**:
- Git repository configuration (SSH URL)
- SSH key management (generate, view public key, import existing)
- Vector search relevance threshold (slider)
- Trash auto-purge duration
- Biometric unlock toggle
- Location permissions

**Post-MVP Settings**:
- Claude API key
- Claude model selection (conversation vs. quick tasks)
- Custom system prompt for Claude
- Duplicate detection sensitivity
- Embedding generation frequency

---

## Technical Requirements

### Technology Stack

- **UI Framework**: SwiftUI
- **CRDT Implementation**: Existing library (Automerge, Yjs, or similar)
- **Vector Embeddings**: Core ML (on-device models)
- **Speech Recognition**: Apple Speech framework
- **Git Integration**: libgit2 or similar
- **Storage**:
  - CRDT database (SQLite or custom)
  - iOS Keychain for secrets
  - iCloud for CRDT sync

### Performance Considerations

- Background batch processing for embeddings (non-blocking)
- Low-priority threads for git push operations
- Efficient vector search indexing
- Minimal battery impact from location services
- Offline-first architecture

### Error Handling

**Prominent Error Messages** for:
- Git push failures (network, auth, conflicts)
- Claude API failures (rate limits, network, invalid key)
- Vector embedding generation failures
- CRDT sync conflicts

**User Actions**:
- Clear error descriptions
- Suggested remediation steps
- Retry options where applicable
- Error log for debugging

---

## Offline Capabilities

### Works Offline:
✅ Create new notes via speech
✅ Manual text note creation
✅ Edit existing notes
✅ Search notes (vector search)
✅ Browse note list
✅ Navigate between notes
✅ Delete notes (move to trash)
✅ Local git commits

### Requires Internet:
❌ Claude conversations
❌ Git push/pull operations
❌ Initial git repository setup

### Sync on Reconnection:
- CRDT changes sync via iCloud
- Git changes pushed in background
- Invisible to user, automatic

---

## Security & Privacy

### Authentication & Authorization
- SSH keys for git (generated or imported)
- Claude API key (user-provided, post-MVP)
- Biometric unlock (Face ID/Touch ID)

### Data Protection
- Encryption at rest for local database
- SSH keys stored in iOS keychain
- API keys stored in iOS keychain
- Location data only "While Using App"
- No telemetry or analytics (open source)

### Privacy Considerations
- On-device speech recognition (no cloud)
- On-device embeddings (no cloud)
- Claude conversations sent to API (post-MVP, user choice)
- Git repo may be private or public (user controls)

---

## Distribution & Development

### Open Source
- Public GitHub repository
- MIT or Apache 2.0 license (TBD)
- Community contributions welcome
- Transparent development

### App Store Distribution
- Public release via Apple App Store
- Free app (no monetization for MVP)
- Potential TestFlight beta before public release

### Development Approach
- MVP first (features listed above)
- Iterative development
- Regular releases
- Community feedback incorporation

---

## Development Phases

### Phase 1: MVP (First Release)

**Core Capture & Sync**:
- Voice capture with Apple Speech
- Manual text note creation
- Raw markdown editor
- Git integration (auto-create, SSH)
- Local git commits + background push
- Trash with auto-purge

**Core Discovery**:
- Note list view (infinite scroll, search)
- Vector search with local embeddings
- Recent notes sorting
- Clickable links

**Core Platform**:
- iPhone single-column layout
- iPad/Mac side-by-side layout
- Biometric unlock
- Encryption at rest
- Location metadata capture

### Phase 2: Intelligence (Post-MVP)

**Claude Integration**:
- API key configuration
- Conversation interface
- RAG with dynamic relevance
- Auto-apply edits with revert
- Conversation history persistence
- Episodic memory pattern

**Smart Features**:
- Auto-generated titles/abstracts
- Duplicate detection + review queue
- Backlinks display
- Link autocomplete

### Phase 3: Advanced (Future)

**Advanced Git**:
- Clone existing repositories
- Manual configuration
- Migration tools for existing Zettelkasten

**Import/Export**:
- Markdown file import
- Batch operations
- Custom metadata mapping

**Power User Features**:
- Advanced search filters
- Graph visualization (optional)
- Bulk editing
- Keyboard shortcuts (Mac)

---

## Success Criteria

### MVP Success Metrics

**Usability**:
- Can capture a note via voice in < 5 seconds
- Can find a note via search in < 10 seconds
- Sync happens invisibly without user intervention
- No data loss in offline/online transitions

**Reliability**:
- Speech recognition accuracy matches iOS dictation
- Vector search returns relevant results
- Git sync handles conflicts gracefully
- CRDT sync resolves without manual intervention

**Performance**:
- Note list scrolls smoothly (60fps)
- Search returns results in < 2 seconds
- Embedding generation doesn't block UI
- Battery impact minimal (<5% per hour of active use)

### Post-MVP Success Metrics

**Claude Integration**:
- Claude conversations feel natural and helpful
- RAG retrieves relevant context reliably
- Auto-edits are accurate >90% of time
- Conversation history provides useful context

**Intelligence**:
- Auto-titles are useful (user keeps >80%)
- Duplicate detection catches real duplicates
- Backlinks reveal meaningful connections

---

## Edge Cases & Constraints

### Git Considerations
- Large repositories (1000+ notes) must perform well
- Binary files in git repo handled gracefully
- Git history preserved through CRDT sync
- Merge conflicts resolved without data loss

### CRDT Considerations
- Clock skew across devices handled
- Concurrent edits to same note resolved
- Large notes (>10MB) supported
- Tombstones for deleted notes managed

### Device Constraints
- Works on older iOS devices (iOS 16+)
- Limited storage handled gracefully
- Low memory situations handled
- Network interruptions don't lose data

### Content Constraints
- Notes with 1000+ backlinks supported
- Unicode and emoji fully supported
- Very long notes (>100KB) handled
- Special markdown syntax preserved

---

## Future Considerations (Out of Scope)

**Not in Current Spec**:
- Multi-user collaboration
- Real-time collaborative editing
- Web interface
- Android version
- Desktop native apps
- Graph visualization (may add post-MVP)
- Tag-based organization (replaced by embeddings)
- Template system
- Plugins/extensions
- Export to other formats (PDF, EPUB, etc.)

These may be considered after MVP and post-MVP phases are complete and stable.

---

## Appendix: Terminology

- **Zettelkasten**: Slip-box method for personal knowledge management
- **CRDT**: Conflict-free Replicated Data Type - enables sync without conflicts
- **RAG**: Retrieval-Augmented Generation - AI with access to external knowledge
- **v7 UUID**: Version 7 UUID (timestamp-based, sortable)
- **Frontmatter**: YAML metadata block at top of markdown files
- **Backlinks**: Notes that link to the current note
- **Episodic Memory**: Pattern for AI to remember context across conversations
- **Vector Embeddings**: Numerical representations of text for semantic search
- **Three-way Merge**: Git merge strategy using common ancestor

---

## Document History

- **v1.0** - 2025-11-05 - Initial specification from Q&A session
