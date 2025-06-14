import AppService
import ObjectEdge
import StateGraph
import SwiftUI
import UniformTypeIdentifiers

struct AudioImportView: View {

  private let service: Service
  private let targetFiles: [TargetFile]
  let onSubmit: @MainActor () -> Void

  init(
    service: Service,
    targets: [TargetFile],
    onSubmit: @escaping @MainActor () -> Void
  ) {
    self.service = service
    self.targetFiles = targets
    self.onSubmit = onSubmit
  }

  var body: some View {
    List(targetFiles, id: \.self) { file in
      HStack {
        VStack(alignment: .leading) {
          Text(file.name)
            .font(.headline)
        }
      }
    }   
    .safeAreaInset(edge: .bottom) { 
      Button("Import") {
        for target in targetFiles {
          _ = service.enqueueTranscribe(target: target)
        }
        onSubmit()
      }
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
    }
  }

}


#Preview {
  AudioImportView(
    service: .init(),
    targets: [
      .init(
        name: "",
        url: .init(filePath: "")!
      )
    ],
    onSubmit: {      
    }
  )
}
