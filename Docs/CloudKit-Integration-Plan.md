# CloudKit Integration Plan for Tone App

## Overview

This document outlines the comprehensive plan for integrating CloudKit synchronization into the Tone app, specifically focusing on handling audio files using CKAsset and maintaining seamless data sync across devices.

## Current Architecture Analysis

### SwiftData Models (V3 Schema)

The current data model consists of:

1. **Item Entity** (`Schemas.V3.Item`)
   - `identifier: String` (unique)
   - `title: String`
   - `createdAt: Date`
   - `audioFilePath: String?` (relative path from documents directory)
   - Relationships: `pinItems`, `tags`, `segments`

2. **Segment Entity** (`Schemas.V3.Segment`)
   - Audio timing data (`startTime`, `endTime: TimeInterval`)
   - Text content (`text: String`)
   - Segment type (`kind: SegmentKind` - text/separator)

3. **Pin Entity** (`Schemas.V3.Pin`)
   - Bookmark references with cue identifiers
   - Creation timestamps

4. **Tag Entity** (`Schemas.V3.Tag`)
   - Organization system with usage tracking
   - Many-to-many relationship with Items

### Current CloudKit Configuration

- **Container**: `iCloud.app.muukii.tone` (configured in Project.swift)
- **Entitlements**: CloudKit services enabled
- **Current Status**: CloudKit container configured but sync not actively implemented

## CloudKit Integration Strategy

### 1. Audio File Handling with CKAsset

#### Current Challenge
Audio files are currently stored as local files with relative paths (`audioFilePath: String?`). This approach doesn't support CloudKit synchronization.

#### Proposed Solution: Dual Storage System

```swift
extension Schemas.V4 {
  @Model
  public final class Item: Hashable {
    // Existing properties...
    @Attribute(.unique)
    public var identifier: String?
    public var title: String = ""
    public var createdAt: Date
    
    // CloudKit Integration Properties
    @Attribute(.externalStorage)
    public var audioFileData: Data?
    
    // Local file management (for backward compatibility)
    public var audioFilePath: String?
    
    // Sync state management
    public var cloudKitSyncState: CloudKitSyncState = .notSynced
    public var audioDownloadProgress: Double = 0.0
    public var lastSyncedAt: Date?
    
    // Computed properties
    public var isAudioAvailableLocally: Bool {
      return audioFileData != nil || (audioFilePath != nil && localFileExists)
    }
    
    public var requiresDownload: Bool {
      return cloudKitSyncState == .uploadedToCloud && audioFileData == nil
    }
  }
  
  public enum CloudKitSyncState: String, Codable, CaseIterable {
    case notSynced        // Local only, not uploaded
    case uploading        // Currently uploading to CloudKit
    case uploadedToCloud  // Available in CloudKit, may not be local
    case downloadedFromCloud // Synced and available locally
    case failed           // Sync failed, requires retry
  }
}
```

### 2. Implementation Phases

#### Phase 1: SwiftData Schema Migration (V3 → V4)
- Add CloudKit-compatible properties to existing models
- Implement migration logic to preserve existing data
- Test schema compatibility with CloudKit

#### Phase 2: CloudKit Service Layer
- Create `CloudKitSyncService` for audio file management
- Implement CKAsset upload/download operations
- Add sync state management and error handling

#### Phase 3: UI Integration
- Add sync status indicators to `AudioListView`
- Implement download progress UI
- Create CloudKit settings panel

#### Phase 4: Background Sync & Optimization
- Implement background download of audio files
- Add intelligent sync policies (WiFi-only options)
- Optimize storage usage with cleanup policies

### 3. Technical Implementation Details

#### CKAsset Integration Pattern

```swift
// Service layer implementation
class CloudKitSyncService {
  
  func uploadAudioFile(_ item: Item) async throws {
    guard let audioData = item.audioFileData else {
      throw CloudKitSyncError.noLocalAudio
    }
    
    // Create temporary file for CKAsset
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(item.identifier ?? UUID().uuidString).m4a")
    
    try audioData.write(to: tempURL)
    
    // CKAsset handles the upload
    let asset = CKAsset(fileURL: tempURL)
    
    // Update CloudKit record
    let record = CKRecord(recordType: "Item", recordID: CKRecord.ID(recordName: item.identifier!))
    record["audioAsset"] = asset
    record["title"] = item.title
    record["createdAt"] = item.createdAt
    
    try await CKContainer.default().privateCloudDatabase.save(record)
    
    // Update local sync state
    item.cloudKitSyncState = .uploadedToCloud
    item.lastSyncedAt = Date()
    
    // Clean up temp file
    try? FileManager.default.removeItem(at: tempURL)
  }
  
  func downloadAudioFile(_ item: Item) async throws {
    let recordID = CKRecord.ID(recordName: item.identifier!)
    let record = try await CKContainer.default().privateCloudDatabase.record(for: recordID)
    
    guard let asset = record["audioAsset"] as? CKAsset,
          let fileURL = asset.fileURL else {
      throw CloudKitSyncError.noRemoteAudio
    }
    
    let audioData = try Data(contentsOf: fileURL)
    item.audioFileData = audioData
    item.cloudKitSyncState = .downloadedFromCloud
    item.lastSyncedAt = Date()
  }
}
```

#### SwiftData CloudKit Configuration

```swift
// App.swift or similar
let container = try ModelContainer(
  for: Schemas.V4.Item.self, 
       Schemas.V4.Segment.self, 
       Schemas.V4.Pin.self, 
       Schemas.V4.Tag.self,
  configurations: ModelConfiguration(
    cloudKitDatabase: .private("iCloud.app.muukii.tone")
  )
)
```

### 4. User Experience Design

#### AudioListView Enhancements

```swift
struct ItemCell: View {
  let item: ItemEntity
  @StateObject private var syncService = CloudKitSyncService()
  
  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(item.title)
        syncStatusView
      }
      
      Spacer()
      
      if item.requiresDownload {
        downloadButton
      } else {
        syncStatusIcon
      }
    }
  }
  
  @ViewBuilder
  private var syncStatusView: some View {
    switch item.cloudKitSyncState {
    case .notSynced:
      Text("Local only")
        .font(.caption)
        .foregroundColor(.secondary)
        
    case .uploading:
      HStack {
        ProgressView()
          .scaleEffect(0.7)
        Text("Uploading...")
          .font(.caption)
      }
      
    case .uploadedToCloud:
      Text("In cloud")
        .font(.caption)
        .foregroundColor(.blue)
        
    case .downloadedFromCloud:
      Text("Synced")
        .font(.caption)
        .foregroundColor(.green)
        
    case .failed:
      Text("Sync failed")
        .font(.caption)
        .foregroundColor(.red)
    }
  }
  
  @ViewBuilder
  private var downloadButton: some View {
    Button("Download") {
      Task {
        try? await syncService.downloadAudioFile(item)
      }
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
  }
}
```

### 5. Storage Strategy & Optimization

#### Intelligent Download Policy
- **Metadata First**: Always sync item metadata (title, segments, pins, tags)
- **Audio On-Demand**: Download audio files only when needed
- **WiFi Priority**: Prefer WiFi for large downloads
- **Storage Management**: Automatic cleanup of old cached files

#### File Size Considerations
- **CKAsset Limit**: 100MB per asset (sufficient for most audio files)
- **Compression**: Consider audio compression for larger files
- **Chunking**: For very large files, implement chunked upload/download

### 6. Error Handling & Reliability

#### Common Error Scenarios
1. **Network Issues**: Retry logic with exponential backoff
2. **Storage Full**: Graceful degradation with user notification
3. **CloudKit Quota**: Handle quota exceeded scenarios
4. **Concurrent Modifications**: Conflict resolution strategies

#### Sync Reliability Measures
```swift
enum CloudKitSyncError: Error, LocalizedError {
  case noLocalAudio
  case noRemoteAudio
  case networkUnavailable
  case quotaExceeded
  case concurrentModification
  
  var errorDescription: String? {
    switch self {
    case .noLocalAudio: return "Audio file not available locally"
    case .noRemoteAudio: return "Audio file not found in cloud"
    case .networkUnavailable: return "Network connection required"
    case .quotaExceeded: return "iCloud storage full"
    case .concurrentModification: return "Item was modified elsewhere"
    }
  }
}
```

### 7. Migration Strategy

#### Backward Compatibility
1. **Dual Path Support**: Maintain both local file path and CloudKit data
2. **Gradual Migration**: Move existing files to CloudKit storage over time
3. **Fallback Mechanism**: Use local files if CloudKit unavailable

#### Migration Implementation
```swift
class DataMigrationService {
  func migrateToCloudKitStorage() async {
    let localItems = await fetchItemsWithLocalFiles()
    
    for item in localItems {
      do {
        // Load local file
        if let localPath = item.audioFilePath,
           let audioData = loadLocalFile(path: localPath) {
          
          // Convert to CloudKit storage
          item.audioFileData = audioData
          item.cloudKitSyncState = .notSynced
          
          // Upload to CloudKit
          try await CloudKitSyncService.shared.uploadAudioFile(item)
        }
      } catch {
        print("Migration failed for item: \(item.identifier ?? "unknown")")
      }
    }
  }
}
```

### 8. Settings & User Control

#### CloudKit Settings Panel
- **Sync Toggle**: Enable/disable CloudKit sync
- **Download Policy**: Auto-download vs. manual download
- **Storage Usage**: Display iCloud usage statistics
- **Network Preference**: WiFi-only downloads option

### 9. Testing Strategy

#### Unit Testing
- CloudKit service operations
- Data migration logic
- Error handling scenarios

#### Integration Testing
- End-to-end sync workflows
- Multi-device synchronization
- Network failure scenarios

#### UI Testing
- Sync status displays
- Download progress indicators
- Error state handling

### 10. Performance Considerations

#### Optimization Strategies
1. **Lazy Loading**: Load audio data only when playing
2. **Background Processing**: Use background tasks for sync operations
3. **Caching Strategy**: Intelligent cache management
4. **Batch Operations**: Group multiple sync operations

#### Memory Management
```swift
// Efficient audio data loading
extension Item {
  func loadAudioDataIfNeeded() async throws -> Data? {
    // Return cached data if available
    if let audioData = self.audioFileData {
      return audioData
    }
    
    // Download from CloudKit if needed
    if cloudKitSyncState == .uploadedToCloud {
      try await CloudKitSyncService.shared.downloadAudioFile(self)
      return self.audioFileData
    }
    
    return nil
  }
}
```

## Implementation Timeline

### Week 1-2: Foundation
- SwiftData schema V4 design and migration
- Basic CloudKit service layer implementation

### Week 3-4: Core Functionality
- CKAsset upload/download implementation
- Sync state management
- Error handling and retry logic

### Week 5-6: UI Integration
- AudioListView sync status indicators
- Download progress UI
- Settings panel implementation

### Week 7-8: Testing & Optimization
- Comprehensive testing
- Performance optimization
- Migration testing with real data

### Week 9-10: Polish & Launch
- Final bug fixes
- Documentation updates
- App Store submission preparation

## Risks & Mitigation

### Technical Risks
1. **SwiftData CloudKit Limitations**: Mitigation through direct CloudKit API usage for audio files
2. **Migration Complexity**: Comprehensive testing and rollback strategies
3. **Storage Costs**: User education and storage management tools

### User Experience Risks
1. **Sync Confusion**: Clear status indicators and user education
2. **Data Loss**: Robust backup and recovery mechanisms
3. **Performance Impact**: Background processing and intelligent caching

## Conclusion

This CloudKit integration plan leverages CKAsset for efficient audio file synchronization while maintaining the existing SwiftData architecture. The phased implementation approach ensures minimal disruption to current functionality while providing robust cross-device synchronization capabilities.

The dual storage system (local + cloud) provides flexibility for users and ensures the app remains functional even with limited connectivity. The comprehensive error handling and sync state management will provide users with clear visibility into the synchronization process.