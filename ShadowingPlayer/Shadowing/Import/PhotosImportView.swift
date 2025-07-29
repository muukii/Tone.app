import AppService
import AVFoundation
import ObjectEdge
import Photos
import PhotosUI
import StateGraph
import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import UIComponents

struct PhotosImportView: View {
    
    private let service: Service
    @Query private var allTags: [TagEntity]
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var targetFiles: [TargetFile] = []
    @State private var processingFiles: [ProcessingFile] = []
    @State private var isProcessing = false
    @State private var showBatchTagPicker = false
    @State private var batchTags: [TagEntity] = []
    @State private var editingTarget: TargetFile?
    @Environment(\.modelContext) private var modelContext
    let onComplete: @MainActor () -> Void
    let onCancel: @MainActor () -> Void
    
    private struct ProcessingFile: Identifiable {
        let id = UUID()
        let name: String
        var status: ProcessingStatus
        var progress: Double = 0.0
        
        enum ProcessingStatus {
            case waiting
            case extractingAudio
            case completed
            case failed(String)
        }
    }
    
    init(
        service: Service,
        onComplete: @escaping @MainActor () -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.service = service
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    private var totalTagCount: Int {
        Set(targetFiles.flatMap { $0.tags }).count
    }
    
    private var canImport: Bool {
        !targetFiles.isEmpty && !isProcessing
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if targetFiles.isEmpty && !isProcessing {
                    photosPickerView
                } else {
                    fileListView
                }
            }
            .navigationTitle("Import from Photos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                if !targetFiles.isEmpty && !isProcessing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            importFiles()
                        }
                        .disabled(!canImport)
                    }
                }
            }
            .sheet(item: $editingTarget, content: sheetTag)
            .sheet(isPresented: $showBatchTagPicker, content: sheetTagForAll)
        }
    }
    
    @ViewBuilder
    private var photosPickerView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 8) {
                    Text("Import from Photos")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Select audio or video files from your Photos library. Videos will be converted to audio for transcription.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .any(of: [.audio, .movie])
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                    Text("Select Media Files")
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            
            Spacer()
        }
        .onChange(of: selectedItems) { _, newItems in
            processSelectedItems(newItems)
        }
    }
    
    @ViewBuilder
    private var fileListView: some View {
        List {
            if !isProcessing {
                batchTagSection
            }
            
            if isProcessing {
                processingSection
            } else {
                targetFilesSection
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if canImport {
                importBottomBar
            }
        }
    }
    
    @ViewBuilder
    private var processingSection: some View {
        Section {
            ForEach(processingFiles) { file in
                HStack(spacing: 12) {
                    Image(systemName: statusIcon(for: file.status))
                        .font(.system(size: 20))
                        .foregroundColor(statusColor(for: file.status))
                        .frame(width: 40, height: 40)
                        .background(statusColor(for: file.status).opacity(0.1))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.system(size: 16, weight: .medium))
                            .lineLimit(1)
                        
                        Text(statusText(for: file.status))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if case .extractingAudio = file.status {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Processing Files")
                .font(.headline)
                .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private var targetFilesSection: some View {
        Section {
            ForEach(targetFiles) { target in
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                            .frame(width: 40, height: 40)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(target.name)
                                .font(.system(size: 16, weight: .medium))
                                .lineLimit(1)
                            
                            Text("\(target.tags.count) tags")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            editingTarget = target
                        } label: {
                            Image(systemName: "tag")
                                .font(.system(size: 18))
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    if !target.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(target.tags) { tag in
                                    if let name = tag.name {
                                        HStack(spacing: 4) {
                                            Text(name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.primary)
                                            Button {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    target.tags.removeAll { $0.id == tag.id }
                                                }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(Color(.systemGray5))
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        } header: {
            HStack {
                Text("Ready to Import")
                    .font(.headline)
                Spacer()
                Button("Select More") {
                    // Reset to picker view
                    selectedItems.removeAll()
                    targetFiles.removeAll()
                    processingFiles.removeAll()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private var batchTagSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Batch Tags")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Apply tags to all files at once")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        showBatchTagPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                    }
                }
                
                if !batchTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(batchTags) { tag in
                                if let name = tag.name {
                                    HStack(spacing: 6) {
                                        Text(name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                batchTags.removeAll { $0.id == tag.id }
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(20)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    @ViewBuilder
    private var importBottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to import")
                        .font(.system(size: 14, weight: .medium))
                    Text("\(targetFiles.count) files • \(totalTagCount) tags")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    importFiles()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Import")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(!canImport)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func processSelectedItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        
        isProcessing = true
        processingFiles = items.map { item in
            ProcessingFile(
                name: item.supportedContentTypes.first?.description ?? "Unknown File",
                status: .waiting
            )
        }
        
        Task {
            await processPhotosPickerItems(items)
        }
    }
    
    @MainActor
    private func processPhotosPickerItems(_ items: [PhotosPickerItem]) async {
        var processedFiles: [TargetFile] = []
        
        for (index, item) in items.enumerated() {
            processingFiles[index].status = .extractingAudio
            
            do {
                if let audioURL = await extractAudioFromPhotosItem(item) {
                    let fileName = audioURL.lastPathComponent
                    let targetFile = TargetFile(name: fileName, url: audioURL)
                    processedFiles.append(targetFile)
                    processingFiles[index].status = .completed
                } else {
                    processingFiles[index].status = .failed("Failed to extract audio")
                }
            } catch {
                processingFiles[index].status = .failed(error.localizedDescription)
            }
        }
        
        // Wait a moment to show completion status
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        targetFiles = processedFiles
        isProcessing = false
        processingFiles.removeAll()
    }
    
    private func extractAudioFromPhotosItem(_ item: PhotosPickerItem) async -> URL? {
        // First try to load as audio directly
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .audio) }) {
            return await loadAudioFromPhotosItem(item)
        }
        
        // If it's a video, extract audio
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            return await extractAudioFromVideo(item)
        }
        
        return nil
    }
    
    private func loadAudioFromPhotosItem(_ item: PhotosPickerItem) async -> URL? {
        return await withCheckedContinuation { continuation in
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data {
                        // Create temporary file
                        let tempDir = FileManager.default.temporaryDirectory
                        let audioURL = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")
                        
                        do {
                            try data.write(to: audioURL)
                            continuation.resume(returning: audioURL)
                        } catch {
                            continuation.resume(returning: nil)
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func extractAudioFromVideo(_ item: PhotosPickerItem) async -> URL? {
        return await withCheckedContinuation { continuation in
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data {
                        Task {
                            let audioURL = await self.extractAudioFromVideoData(data)
                            continuation.resume(returning: audioURL)
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func extractAudioFromVideoData(_ videoData: Data) async -> URL? {
        // Create temporary video file
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent(UUID().uuidString + ".mov")
        let audioURL = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")
        
        do {
            try videoData.write(to: videoURL)
            
            // Use AVAssetExportSession to extract audio
            let asset = AVAsset(url: videoURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                return nil
            }
            
            exportSession.outputURL = audioURL
            exportSession.outputFileType = .m4a
            exportSession.audioMix = nil
            
            await exportSession.export()
            
            // Clean up temporary video file
            try? FileManager.default.removeItem(at: videoURL)
            
            if exportSession.status == .completed {
                return audioURL
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    private func importFiles() {
        for target in targetFiles {
            _ = service.enqueueTranscribe(
                target: target,
                additionalTags: batchTags
            )
        }
        onComplete()
    }
    
    private func statusIcon(for status: ProcessingFile.ProcessingStatus) -> String {
        switch status {
        case .waiting:
            return "clock"
        case .extractingAudio:
            return "waveform"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func statusColor(for status: ProcessingFile.ProcessingStatus) -> Color {
        switch status {
        case .waiting:
            return .orange
        case .extractingAudio:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private func statusText(for status: ProcessingFile.ProcessingStatus) -> String {
        switch status {
        case .waiting:
            return "Waiting..."
        case .extractingAudio:
            return "Extracting audio..."
        case .completed:
            return "Ready"
        case .failed(let error):
            return "Error: \(error)"
        }
    }
    
    private func sheetTagForAll() -> some View {
        TagEditorView(
            service: service,
            currentTags: batchTags,
            allTags: allTags,
            onAddTag: { tag in
                batchTags.append(tag)
            },
            onRemoveTag: { tag in
                batchTags.removeAll(where: { $0 == tag })
            }
        )
        .presentationDetents([.medium, .large])
    }
    
    private func sheetTag(for target: TargetFile) -> some View {
        TagEditorView(
            service: service,
            currentTags: target.tags,
            allTags: allTags,
            onAddTag: { tag in
                target.tags.append(tag)
            },
            onRemoveTag: { tag in
                target.tags.removeAll(where: { $0 == tag })
            }
        )
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    PhotosImportView(
        service: .init(),
        onComplete: {},
        onCancel: {}
    )
}