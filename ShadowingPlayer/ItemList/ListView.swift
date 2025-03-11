import AppService
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ListView: View {

  //  typealias UsingDisplay = PlayerListDisplayView
  typealias UsingDisplay = PlayerListFlowLayoutView
  //  typealias UsingDisplay = PlayerListHorizontalView

  let service: Service

  @Query(sort: \ItemEntity.createdAt, order: .reverse)
  private var itemEntities: [ItemEntity]

  private var isSettingsEnabled: Bool {
    #if DEBUG
      return true
    #else
      return false
    #endif
  }

  @Environment(\.modelContext) var modelContext

  @State private var isInSettings: Bool = false

  @State var path: NavigationPath = .init()

  @State private var isImportingAudioAndSRT: Bool = false
  @State private var isImportingAudio: Bool = false
  @State private var isImportingYouTube: Bool = false

  var body: some View {
    NavigationStack(path: $path) {

      List {
        Section {
          ForEach(itemEntities) { item in
            NavigationLink(value: item) {
              ItemCell(item: item)
            }
            .contextMenu(menuItems: {
              Button("Delete", role: .destructive) {
                // TODO: too direct
                modelContext.delete(item)
              }
            })
          }
        }

      }
      .overlay {
        if itemEntities.isEmpty {
          emptyView()
        }
      }
      .navigationDestination(
        for: ItemEntity.self,
        destination: { item in

          PinEntitiesProvider(targetItem: item) { pins in
            PlayerView<UsingDisplay>(
              playerController: {
                let controller = try! PlayerController(item: item)
                return controller
              },
              pins: pins,
              actionHandler: { action in
                do {
                  switch action {
                  case .onPin(let range):
                    try await service.makePinned(range: range, for: item)
                  case .onTranscribeAgain:
                    try await service.updateTranscribe(for: item)
                    path = .init()
                  }
                } catch {
                  Log.error("\(error.localizedDescription)")
                }
              }
            )
          }

        }
      )
      .toolbar(content: {
        if isSettingsEnabled {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              isInSettings = true
            } label: {
              Image(systemName: "gearshape")
            }
          }
        }
        ToolbarItem(placement: .topBarTrailing) {

          Menu {
            Button("File and SRT") {
              isImportingAudioAndSRT = true
            }
            Button("File (on-device transcribing)") {
              isImportingAudio = true
            }
            Button("YouTube (on-device transcribing)") {
              isImportingYouTube = true
            }
          } label: {
            Text("Import")
          }

        }
      })
      .navigationTitle("Tone")
      .sheet(
        isPresented: $isImportingAudioAndSRT,
        content: {
          AudioAndSubtitleImportView(
            service: service,
            onComplete: {
              isImportingAudioAndSRT = false
            },
            onCancel: {
              isImportingAudioAndSRT = false
            }
          )
        }
      )
      .sheet(
        isPresented: $isImportingYouTube,
        content: {
          YouTubeImportView(
            service: service,
            onComplete: {
              isImportingYouTube = false
            }
          )
        }
      )
      .sheet(
        isPresented: $isInSettings,
        content: {
          SettingsView()
        }
      )
      .modifier(
        ImportModifier(
          isPresented: $isImportingAudio,
          service: service
        )
      )

    }
  }

}

private struct ImportModifier: ViewModifier {

  private let audioUTTypes: Set<UTType> = [
    .mp3, .aiff, .wav, .mpeg4Audio,
  ]

  private struct Selected: Identifiable {
    let id = UUID()
    let selectingFiles: [AudioImportView.TargetFile]
  }

  @Binding var isPresented: Bool
  @State private var selected: Selected?
  private let service: Service

  init(isPresented: Binding<Bool>, service: Service) {
    self._isPresented = isPresented
    self.service = service
  }

  func body(content: Content) -> some View {
    content
      .sheet(
        item: $selected,
        content: { selected in
          AudioImportView(
            service: service,
            targets: selected.selectingFiles,
            onComplete: {
              //                processing = false
            }
          )
        }
      )
      .fileImporter(
        isPresented: $isPresented,
        allowedContentTypes: Array(audioUTTypes),
        allowsMultipleSelection: true,
        onCompletion: { result in
          switch result {
          case .success(let urls):

            // find matching audio files and srt files using same file name
            let audioFiles = Set(
              urls.filter {
                for type in audioUTTypes {
                  if UTType(filenameExtension: $0.pathExtension)?.conforms(to: type) == true {
                    return true
                  }
                }
                return false
              }
            )

            self.selected = Selected(
              selectingFiles: audioFiles.map {

                AudioImportView.TargetFile(
                  name: $0.lastPathComponent,
                  url: $0
                )
              }
            )

          case .failure(let failure):
            print(failure)
          }
        }
      )
  }
}

private func emptyView() -> some View {
  ContentUnavailableView {
    Text("Let's add your own contents")
  } description: {
    Text("You can add your own contents from the import button on the top right corner.")
  } actions: {
    // No Actions for now
  }
}

private struct ItemCell: View {

  let title: String

  init(item: ItemEntity) {
    self.title = item.title
  }

  init(title: String) {
    self.title = title
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("\(title)")
    }
  }
}

struct PinEntitiesProvider<Content: View>: View {

  @Query var pinEntities: [PinEntity]

  private let content: ([PinEntity]) -> Content

  init(targetItem: ItemEntity, @ViewBuilder content: @escaping ([PinEntity]) -> Content) {

    self.content = content

    let predicate = #Predicate<PinEntity> { [identifier = targetItem.persistentModelID] in
      $0.item?.persistentModelID == identifier
    }

    self._pinEntities = Query.init(filter: predicate, sort: \.createdAt)
  }

  var body: some View {
    content(pinEntities)
  }

}

#Preview(
  "Empty",
  body: {
    emptyView()
  })

#Preview {
  Form {
    ItemCell(title: "Hello, Tone.")
  }
}

#Preview {

  ListView(service: .init())

}
