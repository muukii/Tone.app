import AppService
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AudioListView: View {

  //  typealias UsingDisplay = PlayerListDisplayView
  typealias UsingDisplay = PlayerListFlowLayoutView
  //  typealias UsingDisplay = PlayerListHorizontalView

  let service: Service
  let openAIService: OpenAIService?

  @Query(sort: \ItemEntity.title, order: .reverse)
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
  @State private var tagEditingItem: ItemEntity?
  
  @Query var allTags: [TagEntity]

  private let onSelect: (ItemEntity) -> Void

  init(
    service: Service,
    openAIService: OpenAIService?,
    onSelect: @escaping (ItemEntity) -> Void
  ) {
    self.service = service
    self.openAIService = openAIService
    self.onSelect = onSelect
  }

  var body: some View {
    NavigationStack(path: $path) {

      List {
        Section {
          ForEach(itemEntities) { item in
            Button {
              onSelect(item)
            } label: {
              AudioItemCell(item: item)
            }
            .contextMenu(menuItems: {
              Button("Delete", role: .destructive) {
                // TODO: too direct
                modelContext.delete(item)
              }
              Button("Tags") {
                tagEditingItem = item
              }
              if let openAIService {
                Menu("Cloud Transcription") {
                  ForEach(OpenAIService.TranscriptionModel.allCases, id: \.rawValue) { model in
                    Button("\(model.rawValue)") {
                      Task { [openAIService] in
                        do {
                          let result = try await openAIService.transcribe(
                            fileURL: item.audioFileAbsoluteURL, model: model)
                          try await service.updateTranscription(for: item, with: result)
                        } catch {
                          Log.error("\(error.localizedDescription)")
                        }
                      }
                    }
                  }
                }
              }
            })
          }
        }

      }
      .safeAreaPadding(.bottom, 50)
      .overlay {
        if itemEntities.isEmpty {
          emptyView()
        }
      }
      /*
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
                  case .onRename(let title):
                    try await service.renameItem(item: item, newTitle: title)
                  }
                } catch {
                  Log.error("\(error.localizedDescription)")
                }
              }
            )
          }

        }
      )
       */
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
        item: $tagEditingItem,
        content: { item in
          TagEditorView(
            currentTags: item.tags ?? [],
            allTags: allTags,
            onAddTag: { tag in
              item.tags?.append(tag)
            },
            onRemoveTag: { tag in
              item.tags?.removeAll(where: { $0 == tag })
            }
          )
      })
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
