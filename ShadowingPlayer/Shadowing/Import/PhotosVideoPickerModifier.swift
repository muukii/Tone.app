import SwiftUI
import PhotosUI
import AppService
import AVKit
import UniformTypeIdentifiers

// Import errors
enum ImportError: LocalizedError {
  case noVideosProcessed
  case audioExtractionFailed(Error)
  
  var errorDescription: String? {
    switch self {
    case .noVideosProcessed:
      return "Failed to process any videos. Please try again."
    case .audioExtractionFailed(let error):
      return "Failed to extract audio: \(error.localizedDescription)"
    }
  }
}

struct PhotosVideoPickerModifier: ViewModifier {
  
  @Binding var isPresented: Bool
  @State var selectedItems: [PhotosPickerItem] = []
  @State var audioTargets: [TargetFile] = []
  @State var showImportView: Bool = false
  @State var isProcessing: Bool = false
  @State var processingError: Error?
  @State var processingStatus: String = ""
  let service: Service
  let defaultTag: TagEntity?
  
  init(isPresented: Binding<Bool>, service: Service, defaultTag: TagEntity? = nil) {
    self._isPresented = isPresented
    self.service = service
    self.defaultTag = defaultTag
  }
  
  func body(content: Content) -> some View {
    content
      .photosPicker(
        isPresented: $isPresented,
        selection: $selectedItems,
        matching: .videos
      )
      .onChange(of: selectedItems) { _, newItems in
        if !newItems.isEmpty {
          Task {
            await processSelectedVideos(newItems)
          }
        }
      }
      .sheet(isPresented: $showImportView) {
        AudioImportView(
          service: service,
          targets: audioTargets,
          defaultTag: defaultTag,
          onSubmit: {
            audioTargets = []
            selectedItems = []
            showImportView = false
          }
        )
      }
      .overlay {
        if isProcessing {
          ZStack {
            Color.black.opacity(0.5)
              .ignoresSafeArea()
            
            VStack(spacing: 16) {
              ProgressView()
                .scaleEffect(1.5)
              Text(processingStatus)
                .foregroundColor(.white)
                .font(.headline)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
          }
        }
      }
      .alert("Import Error", isPresented: .constant(processingError != nil)) {
        Button("OK") {
          processingError = nil
        }
      } message: {
        if let error = processingError {
          Text(error.localizedDescription)
        }
      }
  }
  
  @MainActor
  private func processSelectedVideos(_ items: [PhotosPickerItem]) async {
    
    isProcessing = true
    defer { 
      isProcessing = false 
      processingStatus = ""
    }
    
    selectedItems = []
    
    var targets: [TargetFile] = []
    
    for (index, item) in items.enumerated() {
      do {
        processingStatus = "Processing video \(index + 1) of \(items.count)..."
        
        // Create temporary file URL for video
        let videoTempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent(UUID().uuidString)
          .appendingPathExtension("mov")
        
        // Load video data from PhotosPickerItem
        guard let data = try await item.loadTransferable(type: Data.self) else {
          Log.warning("Could not load video from PhotosPickerItem at index \(index)")
          continue
        }
        
        // Write video data to temporary file
        try data.write(to: videoTempURL)
        
        Log.debug("Loaded video as Data, size: \(data.count) bytes")
        
        // Verify the video file exists and has content
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: videoTempURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        guard fileSize > 0 else {
          Log.warning("Video file is empty at: \(videoTempURL)")
          try? FileManager.default.removeItem(at: videoTempURL)
          continue
        }
        
        processingStatus = "Extracting audio from video \(index + 1)..."
        
        // Extract audio from video
        let audioURL = try await AudioExtractor.extractAudio(from: videoTempURL)
        
        // Clean up the temporary video file immediately
        try? FileManager.default.removeItem(at: videoTempURL)
        
        Log.debug("Successfully extracted audio to \(audioURL)")
        
        // Create target file with the extracted audio
        let target = TargetFile(
          name: "Video \(index + 1)",
          url: audioURL
        )
        targets.append(target)
        
        Log.debug("Successfully processed video \(index + 1)")
        
      } catch {
        Log.error("Failed to process video \(index): \(error)")
        processingError = ImportError.audioExtractionFailed(error)
      }
    }
    
    Log.debug("Processed \(targets.count) videos out of \(items.count) selected")
    
    if !targets.isEmpty {
      audioTargets = targets
      showImportView = true
    } else {
      Log.warning("No videos were successfully processed")
      if processingError == nil {
        processingError = ImportError.noVideosProcessed
      }
    }
  }
}

extension View {
  func photosVideoPicker(isPresented: Binding<Bool>, service: Service) -> some View {
    self.modifier(PhotosVideoPickerModifier(isPresented: isPresented, service: service))
  }
}
