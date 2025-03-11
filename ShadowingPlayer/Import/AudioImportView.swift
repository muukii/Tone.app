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
    StoreReader(viewModel) { state in 
      List(state.targetFiles, id: \._id) { store in
        StoreReader(store) { state in 
          HStack {
            VStack(alignment: .leading) {
              Text(state.file.name)
                .font(.headline)              
            }
            Spacer()
            if state.isProcessing {
              ProgressView()
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

extension Store {
  /// waiting‘  /// https://github.com/VergeGroup/swift-verge/pull/519
  var _id: ObjectIdentifier {
    ObjectIdentifier(self)
  }
}

final class AudioImportViewModel: StoreDriverType {
  
  @Tracking
  struct TargetFileState {
    
    let file: AudioImportView.TargetFile
    var isProcessing: Bool
    
    init(initialState: AudioImportView.TargetFile) {
      self.file = initialState
      self.isProcessing = false
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

      await withTaskGroup(of: Void.self) { group in

        for fileStore in files {

          group.addTask {
            defer {
              fileStore.commit {
                $0.isProcessing = false
              }
            }
            do {
              let file = fileStore.state.file
              fileStore.commit {
                $0.isProcessing = true
              }
              try await service.transcribe(
                title: file.name,
                audioFileURL: file.url
              )
            } catch {
              print("Error processing \(fileStore.name): \(error)")
            }
          }
        }

        await group.waitForAll()

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
