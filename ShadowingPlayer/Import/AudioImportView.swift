import AppService
import SwiftUI
import UniformTypeIdentifiers
import Verge

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

  @StoreObject private var viewModel: AudioImportViewModel
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
    StoreReader(viewModel) { $state in
      List(state.targetFiles, id: \.self) { store in
        StoreReader(store) { $state in
          HStack {
            VStack(alignment: .leading) {
              Text(state.file.name)
                .font(.headline)
            }
            Spacer()
            switch state.status {
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
      }
    }
    .onAppear {
      viewModel.startProcessing()
    }
  }

}

final class AudioImportViewModel: StoreDriverType {

  @Tracking
  struct TargetFileState {

    enum Status {
      case waiting
      case processing
      case completed
      case failed
    }

    let file: AudioImportView.TargetFile

    var status: Status = .waiting

    init(initialState: AudioImportView.TargetFile) {
      self.file = initialState
    }
  }

  @Tracking
  struct State {

    var targetFiles: [Store<TargetFileState, Never>]
    var isProcessing: Bool = false

  }

  let store: Store<State, Never>
  let service: Service

  init(
    targets: [AudioImportView.TargetFile],
    service: Service
  ) {
    self.service = service
    self.store = .init(
      initialState: .init(
        targetFiles: targets.map {
          .init(initialState: .init(initialState: $0))
        }
      )
    )
  }

  func startProcessing() {

    guard !store.state.isProcessing else {
      return
    }

    store.commit {
      $0.isProcessing = true
    }

    let files = state.targetFiles

    store.task { [store, service] in

      for fileStore in files {

        defer {
          fileStore.commit {
            $0.status = .completed
          }
        }
        do {
          let file = fileStore.state.file
          fileStore.commit {
            $0.status = .processing
          }
          try await service.transcribe(
            title: file.name,
            audioFileURL: file.url
          )
        } catch {
          print("Error processing \(fileStore.name): \(error)")
          fileStore.commit {
            $0.status = .failed
          }
        }

      }

      store.commit {
        $0.isProcessing = false
      }
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
