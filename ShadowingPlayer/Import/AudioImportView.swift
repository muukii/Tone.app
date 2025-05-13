import AppService
import ObjectEdge
import StateGraph
import SwiftUI
import UniformTypeIdentifiers

struct AudioImportView: View {

  struct TargetFile {
    let name: String
    let url: URL

    init(name: String, url: URL) {
      self.name = name
      self.url = url
    }
  }

  private let service: Service

  @ObjectEdge private var viewModel: AudioImportViewModel
  let onComplete: @MainActor () -> Void

  init(
    service: Service,
    targets: [TargetFile],
    onComplete: @escaping @MainActor () -> Void
  ) {
    self.service = service
    self.onComplete = onComplete
    self._viewModel = .init(
      wrappedValue: AudioImportViewModel(
        targets: targets,
        service: service
      )
    )
  }

  var body: some View {
    List(viewModel.targetFiles, id: \.self) { store in
      HStack {
        VStack(alignment: .leading) {
          Text(store.file.name)
            .font(.headline)
        }
        Spacer()
        switch store.status {
        case .waiting:
          Image(systemName: "circle")
        case .processing:
          ProgressView()
        case .completed:
          Image(systemName: "checkmark")
        case .failed:
          Image(systemName: "xmark")
        }
      }
    }
    .onAppear {
      viewModel.startProcessing()
    }
  }

}

@MainActor
final class AudioImportViewModel {

  final class TargetFileState: Hashable {
        
    static func == (lhs: AudioImportViewModel.TargetFileState, rhs: AudioImportViewModel.TargetFileState) -> Bool {
      lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
      ObjectIdentifier(self).hash(into: &hasher)
    }

    enum Status {
      case waiting
      case processing
      case completed
      case failed
    }

    let file: AudioImportView.TargetFile

    @GraphStored
    var status: Status = .waiting

    init(file: AudioImportView.TargetFile) {
      self.file = file
    }
  }

  @GraphStored
  var targetFiles: [TargetFileState]

  @GraphStored
  var isProcessing: Bool = false

  let service: Service

  init(
    targets: [AudioImportView.TargetFile],
    service: Service
  ) {
    self.service = service

    self.targetFiles = targets.map {
      .init(file: $0)
    }

  }

  func startProcessing() {

    guard !isProcessing else {
      return
    }

    self.isProcessing = true

    let files = targetFiles

    Task { [service] in

      for fileStore in files {

        defer {
          fileStore.status = .completed
        }
        do {
          let file = fileStore.file

          fileStore.status = .processing

          try await service.transcribe(
            title: file.name,
            audioFileURL: file.url
          )
        } catch {
          fileStore.status = .failed
        }

      }

      self.isProcessing = false
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
