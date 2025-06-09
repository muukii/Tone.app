# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

```bash
# Build using Tuist (recommended)
tuist install            # Install dependencies
tuist generate --no-open # Generate Xcode project without opening
tuist build              # Build all schemes

# Alternative: Build specific schemes
tuist build ActivityContent
tuist build AppService
tuist build LiveActivity
tuist build Tone
```

Required tools:
- Xcode 16.2+ (for Swift 6.0 support)
- iOS 18.0+ deployment target
- mise for tool version management

## Project Overview

**Tone** is a sophisticated iOS language learning app focused on **shadowing practice** - a technique where users listen to audio and repeat it to improve pronunciation and fluency.

### Navigation Architecture
- Uses **Platter UI** - a custom split-view interface with expandable player
- Main content: `AudioListView` for browsing audio items
- Player slides up from bottom with full shadowing controls
- Previous tab-based navigation is commented out in favor of Platter

### Target Structure
- **Tone** (main app): iPhone + Mac Catalyst, SwiftUI-based
- **AppService** (static library): Core business logic, data models, transcription services
- **LiveActivity** (widget extension): Placeholder for background media controls (not yet functional)
- **ActivityContent** (framework): Shared models for Live Activities

### Key Architectural Patterns
- **StateGraph**: Custom reactive state management with automatic dependency tracking
  - Replaces Observable/Combine with DAG-based state propagation
  - Features: lazy evaluation, caching, type-safe reactive programming
  - Uses `@GraphStored` for state and `@ObjectEdge` for view models
- **SwiftData**: Persistence layer with V2 schema
  - **Warning**: V1→V2 migration currently deletes all data
  - Embedded subtitle storage (migrated from file paths)
  - CloudKit configured but disabled
- **Service Layer Pattern**: Clean separation between UI and business logic
  - `RootDriver`: App-wide state coordination
  - `Service`: Core operations (import, transcribe, persistence)
  - `OpenAIService`: External API integration

## Core Features

### 1. Audio Import & Transcription
- **Import Methods**:
  - Audio + SRT files (batch support with auto-pairing)
  - Audio-only with on-device transcription
  - YouTube URL with audio extraction and transcription
- **Transcription Architecture**:
  - **Primary**: WhisperKit (local, on-device) with configurable models
  - **Secondary**: OpenAI API support (implemented but not exposed in UI)
  - Word-level timestamp precision for accurate synchronization

### 2. Shadowing Player
- **Audio Engine**: Built on AVAudioEngine with AudioTimeline system
  - Multi-track support with sample-accurate synchronization
  - Variable playback speed (0.3x-1.0x) using AVAudioUnitTimePitch
  - Recording overlay synchronized with playback position
- **UI Features**:
  - Chunk-based subtitle display (groups by timing gaps >0.08s)
  - Real-time highlighting with 5ms polling intervals
  - Auto-scrolling with manual override detection
  - Contextual actions: copy, pin, add to flashcard
- **Interaction**:
  - Voice recording with press-and-hold gesture
  - Repeat mode with range selection
  - Pin/bookmark system for important segments
  - Space bar keyboard shortcut for play/pause

### 3. Anki Integration (Currently Disabled)
- Spaced repetition system using SuperMemo-2 algorithm
- Features: vocabulary cards, CSV import, AI-generated translations
- Disabled in MainTabView (lines 54-59)
- Separate SwiftData container from main app data

## Data Models & Persistence

### V2 Schema Structure
- **Item**: Core audio learning entity
  - Audio file path (relative to documents)
  - Embedded subtitle data as JSON
  - Relationships: One-to-many with Pin, Many-to-many with Tag
- **Pin**: Bookmarked audio segments
  - Composite ID: `{itemID}{startCueID}-{endCueID}`
  - Cascade delete with parent Item
- **Tag**: Organizational system (new in V2)
  - Usage tracking with lastUsedAt
  - Nullify delete rule

### Migration Issues
- V1→V2 migration is **destructive** (deletes all data)
- Migration code commented out due to errors
- Missing subtitle file → embedded data conversion

## Key Dependencies

- **Audio**: AudioKit, WhisperKit, DSWaveformImageViews
- **UI**: Custom submodules (SwiftUIRingSlider, DynamicList, SwiftUIStack)
- **State**: StateGraph (VergeGroup/swift-state-graph)
- **Media**: YouTubeKit, Alamofire
- **Data**: SwiftData with CloudKit configuration

## Configuration Requirements

- OpenAI API key stored in UserDefaults (not in code)
- Microphone permissions for voice recording
- Audio background mode enabled
- CloudKit container: iCloud.app.muukii.tone (currently disabled)

## Common Development Commands

```bash
# Build the project
tuist install          # Install dependencies
tuist generate --no-open  # Generate Xcode project without opening
tuist build            # Build all schemes

# Regenerate project after dependency changes
tuist install && tuist generate -n

# Clean and regenerate (if build issues)
tuist clean && tuist generate -n

# Update submodules (custom UI components)
git submodule update --recursive --remote
```

## Technical Highlights

### Audio Engineering
- Sample-accurate multi-track synchronization
- Custom Clock implementation for precise timing
- Host time conversions for audio scheduling
- Proper audio session interruption handling
- Recording with playback offset management

### Performance Optimizations
- Lazy loading with DynamicList
- Efficient diffable data source snapshots
- Conditional UI updates in background
- Frame-based audio calculations
- StateGraph's O(1) cached value access

### Current Limitations
1. **Live Activities**: Only placeholder implementation
2. **OpenAI Transcription**: Backend ready but no UI option
3. **Data Migration**: V1→V2 deletes user data
4. **Export Features**: No export functionality
5. **Anki Integration**: Implemented but disabled

The app demonstrates professional-grade engineering with innovative UI patterns and sophisticated audio processing, making it a powerful tool for language learners practicing shadowing techniques.