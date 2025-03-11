import AppService
import SwiftUI
import UniformTypeIdentifiers

struct AudioImportView: View {
  
  struct TargetFile: Identifiable {
    var id: URL { url }
    var name: String
    var url: URL
    var isProcessing: Bool
  }
  
  private let service: Service
  @State private var targetFiles: [TargetFile]
  let onComplete: @MainActor () -> Void

  init(
    service: Service,
    targets: [TargetFile],
    onComplete: @escaping @MainActor () -> Void
  ) {
    self.service = service
    self.targetFiles = targets
    self.onComplete = onComplete
  }

  var body: some View {
    List(targetFiles) { file in
      HStack {
        VStack(alignment: .leading) {
          Text(file.name)
            .font(.headline)
          if file.isProcessing {
            Text("処理中...")
              .foregroundColor(.secondary)
          }
        }
        Spacer()
        if file.isProcessing {
          ProgressView()
        }
      }
    }
    .task {
      await withTaskGroup(of: Void.self) { group in
        for index in targetFiles.indices {
          group.addTask {
            await processFile(at: index)
          }
        }
      }
      await onComplete()
    }
  }
  
  @MainActor
  private func processFile(at index: Int) async {
    targetFiles[index].isProcessing = true
    defer { targetFiles[index].isProcessing = false }

    do {
      try await service.transcribe(
        title: targetFiles[index].name,
        audioFileURL: targetFiles[index].url
      )
    } catch {
      print("Error processing \(targetFiles[index].name): \(error)")
    }
  }
}

#Preview {
//  AudioImportView(
//    service: .mock,
//    urls: [
//      URL(string: "file://test1.mp3")!,
//      URL(string: "file://test2.mp3")!
//    ],
//    onComplete: {}
//  )
}
