import AppService
import PhotosUI
import SwiftData
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct PhotosImportView: View {
  
  let service: Service
  let onComplete: () -> Void
  
  @State private var selectedItems: [PhotosPickerItem] = []
  @State private var isProcessing = false
  @State private var processingStatus: String = ""
  @State private var batchTag: String = ""
  @State private var individualTags: [String: String] = [:]
  @State private var targetFiles: [TargetFile] = []
  @State private var errorMessage: String?
  
  private let maxSelectionCount = 10
  
  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        
        if isProcessing {
          processingView
        } else if targetFiles.isEmpty {
          selectionView
        } else {
          confirmationView
        }
        
      }
      .padding()
      .navigationTitle("Import from Photos")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            onComplete()
          }
          .disabled(isProcessing)
        }
        
        if !targetFiles.isEmpty && !isProcessing {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Import") {
              submitImport()
            }
          }
        }
      }
      .alert("Error", isPresented: .constant(errorMessage != nil)) {
        Button("OK") {
          errorMessage = nil
        }
      } message: {
        if let errorMessage = errorMessage {
          Text(errorMessage)
        }
      }
    }
  }
  
  private var selectionView: some View {
    VStack(spacing: 20) {
      Text("Select audio or video files from your Photos library")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      
      PhotosPicker(
        selection: $selectedItems,
        maxSelectionCount: maxSelectionCount,
        matching: .any(of: [.audiovisualContent])
      ) {
        Label("Choose Files", systemImage: "photo.on.rectangle.angled")
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(10)
      }
      .onChange(of: selectedItems) { _, newItems in
        if !newItems.isEmpty {
          processSelectedItems(newItems)
        }
      }
      
      Text("Select up to \(maxSelectionCount) files. Videos will be converted to audio.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }
  
  private var processingView: some View {
    VStack(spacing: 20) {
      ProgressView()
        .scaleEffect(1.2)
      
      Text(processingStatus)
        .multilineTextAlignment(.center)
      
      Text("Processing selected files...")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
  
  private var confirmationView: some View {
    VStack(spacing: 20) {
      Text("Ready to Import")
        .font(.headline)
      
      // Batch tag input
      VStack(alignment: .leading, spacing: 8) {
        Text("Batch Tag (optional)")
          .font(.subheadline)
          .fontWeight(.medium)
        TextField("Tag for all files", text: $batchTag)
          .textFieldStyle(RoundedBorderTextFieldStyle())
      }
      
      // File list with individual tags
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(targetFiles, id: \.name) { file in
            fileRow(for: file)
          }
        }
      }
      .frame(maxHeight: 300)
    }
  }
  
  private func fileRow(for file: TargetFile) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: file.name.hasSuffix(".m4a") ? "music.note" : "waveform")
          .foregroundStyle(.blue)
        Text(file.name)
          .font(.subheadline)
          .fontWeight(.medium)
          .lineLimit(1)
        Spacer()
      }
      
      TextField("Individual tag (optional)", text: Binding(
        get: { individualTags[file.name] ?? "" },
        set: { individualTags[file.name] = $0 }
      ))
      .textFieldStyle(RoundedBorderTextFieldStyle())
      .font(.caption)
    }
    .padding()
    .background(Color(UIColor.secondarySystemBackground))
    .cornerRadius(8)
  }
  
  private func processSelectedItems(_ items: [PhotosPickerItem]) {
    Task {
      await MainActor.run {
        isProcessing = true
        processingStatus = "Loading selected files..."
        targetFiles = []
      }
      
      var processedFiles: [TargetFile] = []
      
      for (index, item) in items.enumerated() {
        await MainActor.run {
          processingStatus = "Processing file \(index + 1) of \(items.count)..."
        }
        
        do {
          if let targetFile = await processPhotoPickerItem(item) {
            processedFiles.append(targetFile)
          }
        } catch {
          await MainActor.run {
            errorMessage = "Failed to process file: \(error.localizedDescription)"
          }
        }
      }
      
      await MainActor.run {
        targetFiles = processedFiles
        isProcessing = false
        processingStatus = ""
        
        if targetFiles.isEmpty {
          errorMessage = "No compatible files were found in your selection."
        }
      }
    }
  }
  
  private func processPhotoPickerItem(_ item: PhotosPickerItem) async -> TargetFile? {
    // Load the item data
    guard let data = try? await item.loadTransferable(type: Data.self) else {
      return nil
    }
    
    // Create temporary file
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = item.itemIdentifier ?? UUID().uuidString
    let tempURL = tempDir.appendingPathComponent(fileName)
    
    do {
      try data.write(to: tempURL)
      
      // Check if it's a video file that needs conversion
      let asset = AVURLAsset(url: tempURL)
      let tracks = try await asset.loadTracks(withMediaType: .video)
      
      if !tracks.isEmpty {
        // It's a video, convert to audio
        return try await convertVideoToAudio(from: tempURL, originalName: fileName)
      } else {
        // It's already an audio file
        let audioFileName = (fileName as NSString).deletingPathExtension + ".m4a"
        return TargetFile(name: audioFileName, url: tempURL)
      }
    } catch {
      print("Error processing file: \(error)")
      return nil
    }
  }
  
  private func convertVideoToAudio(from videoURL: URL, originalName: String) async throws -> TargetFile {
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent((originalName as NSString).deletingPathExtension + ".m4a")
    
    // Remove existing file if it exists
    try? FileManager.default.removeItem(at: outputURL)
    
    let asset = AVURLAsset(url: videoURL)
    
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
      throw NSError(domain: "ConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a
    
    return try await withCheckedThrowingContinuation { continuation in
      exportSession.exportAsynchronously {
        switch exportSession.status {
        case .completed:
          continuation.resume(returning: TargetFile(
            name: outputURL.lastPathComponent,
            url: outputURL
          ))
        case .failed:
          continuation.resume(throwing: exportSession.error ?? NSError(
            domain: "ConversionError",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Export failed"]
          ))
        case .cancelled:
          continuation.resume(throwing: NSError(
            domain: "ConversionError",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]
          ))
        default:
          continuation.resume(throwing: NSError(
            domain: "ConversionError",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Unknown export status"]
          ))
        }
      }
    }
  }
  
  private func submitImport() {
    let finalTargetFiles = targetFiles.map { file in
      var modifiedFile = file
      
      // Apply batch tag if provided
      if !batchTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        modifiedFile.tags.append(batchTag.trimmingCharacters(in: .whitespacesAndNewlines))
      }
      
      // Apply individual tag if provided
      if let individualTag = individualTags[file.name],
         !individualTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        modifiedFile.tags.append(individualTag.trimmingCharacters(in: .whitespacesAndNewlines))
      }
      
      return modifiedFile
    }
    
    Task {
      do {
        try await service.importAudio(finalTargetFiles)
        await MainActor.run {
          onComplete()
        }
      } catch {
        await MainActor.run {
          errorMessage = "Import failed: \(error.localizedDescription)"
        }
      }
    }
  }
}