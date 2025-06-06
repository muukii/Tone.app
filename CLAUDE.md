# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

### Building the Project

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

## Project Architecture

**Tone** is an iOS language learning app for shadowing practice (listening and repeating audio for pronunciation improvement).

### Target Structure
- **Tone** (main app): iPhone + Mac Catalyst, SwiftUI-based
- **AppService** (static library): Core business logic, data models, transcription services
- **LiveActivity** (widget extension): Background media controls 
- **ActivityContent** (framework): Shared models for Live Activities

### Key Architectural Patterns
- **StateGraph**: Reactive state management (replaces Observable/Combine)
- **SwiftData**: Persistence layer with V2 schema migration
- **Modular design**: Service layer separated from UI
- **Dependency injection**: Using `@ObjectEdge` and constructor injection

## Core Features

1. **Audio Import & Transcription**
   - Multiple sources: audio+subtitle files, YouTube downloads, audio-only with auto-transcription
   - Dual transcription: WhisperKit (local) + OpenAI API (cloud)
   - Word-level timestamp generation

2. **Shadowing Player**
   - Synchronized audio playback with subtitle highlighting
   - Chunk-based navigation (jump between words/phrases)
   - Voice recording for pronunciation practice
   - Repeating modes and variable speed playback
   - Pin/bookmark system for important segments

3. **Anki Integration**
   - Vocabulary card creation and export
   - Expression detail views for study

## Data Models (V2 Schema)

Primary entity: `ItemEntity` with:
- Audio file path (relative storage)
- Subtitle data with word-level timestamps
- Pin items (bookmarked segments)
- Tag system for organization

## Key Dependencies

**Audio Processing**: AudioKit, WhisperKit, DSWaveformImageViews
**UI Components**: Custom submodules (SwiftUIRingSlider, DynamicList, etc.)
**State Management**: StateGraph (custom reactive framework)
**Networking**: Alamofire, YouTubeKit
**Data**: SwiftData with CloudKit entitlements (currently disabled)

## Configuration Requirements

- OpenAI API key for cloud transcription (Environment/OpenAIServiceKey.swift)
- Microphone permissions for voice recording
- Audio background mode enabled
- CloudKit container: iCloud.app.muukii.tone

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

## Architecture Notes

- **Audio Session Management**: Handles interruptions and background playback
- **Live Activities**: Media controls persist in Dynamic Island/Lock Screen  
- **Transcript Synchronization**: Real-time highlighting during audio playback
- **Modular Submodules**: UI components maintained as separate git repositories
- **File Storage**: Relative paths for audio files, enables future cloud sync

The app follows modern iOS patterns with SwiftUI, async/await, and actors for concurrent audio processing.
