import SwiftUI
import PhotosUI
import AppService
import AVKit
import UniformTypeIdentifiers

// Import errors
enum ImportError: LocalizedError {
  case noVideosProcessed
  
  var errorDescription: String? {
    switch self {
    case .noVideosProcessed:
      return "Failed to process any videos. Please try again."
    }
  }
}

struct PhotosVideoPickerModifier: ViewModifier {
  
  @Binding var isPresented: Bool
  @State var selectedItems: [PhotosPickerItem] = []
  @State var videoTargets: [TargetFile] = []
  @State var showImportView: Bool = false
  @State var isProcessing: Bool = false
  @State var processingError: Error?
  let service: Service
  
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
        VideoImportView(
          service: service,
          targets: videoTargets,
          onSubmit: {
            videoTargets = []
            selectedItems = []
            showImportView = false
          }
        )
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
    defer { isProcessing = false }
    
    selectedItems = []
    
    var targets: [TargetFile] = []
    
    for (index, item) in items.enumerated() {
      do {
        // Create temporary file URL
        let tempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent(UUID().uuidString)
          .appendingPathExtension("mov")
        
        // Load video data from PhotosPickerItem
        // First try as Data
        guard let data = try await item.loadTransferable(type: Data.self) else {
          Log.warning("Could not load video from PhotosPickerItem at index \(index)")
          continue
        }
        
        // Write data to temporary file
        try data.write(to: tempURL)
        
        Log.debug("Loaded video as Data, size: \(data.count) bytes")
        
        // Verify the file exists and has content
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        guard fileSize > 0 else {
          Log.warning("Video file is empty at: \(tempURL)")
          try? FileManager.default.removeItem(at: tempURL)
          continue
        }
        
        Log.debug("Video file created at \(tempURL) with size \(fileSize) bytes")
        
        // Create target file with generated name
        let target = TargetFile(
          name: "Video \(index + 1)",
          url: tempURL
        )
        targets.append(target)
        
        Log.debug("Successfully processed video \(index + 1)")
        
      } catch {
        Log.error("Failed to process video \(index): \(error)")
        processingError = error
      }
    }
    
    Log.debug("Processed \(targets.count) videos out of \(items.count) selected")
    
    if !targets.isEmpty {
      videoTargets = targets
      showImportView = true
    } else {
      Log.warning("No videos were successfully processed")
      processingError = ImportError.noVideosProcessed
    }
  }
}

extension View {
  func photosVideoPicker(isPresented: Binding<Bool>, service: Service) -> some View {
    self.modifier(PhotosVideoPickerModifier(isPresented: isPresented, service: service))
  }
}
