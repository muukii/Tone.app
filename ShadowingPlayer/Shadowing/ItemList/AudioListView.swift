import AppService
import CollectionView
import SwiftData
import SwiftUI
import UIComponents
import UniformTypeIdentifiers

struct AudioListView: View {

  //  typealias UsingDisplay = PlayerListDisplayView
  typealias UsingDisplay = PlayerListFlowLayoutView
  //  typealias UsingDisplay = PlayerListHorizontalView

  let service: Service
  let openAIService: OpenAIService?

  @Query(sort: \ItemEntity.title, order: .reverse)
  private var items: [ItemEntity]

  @Query(sort: \TagEntity.name)
  private var tags: [TagEntity]

  private var isSettingsEnabled: Bool {
    #if DEBUG
      return true
    #else
      return false
    #endif
  }

  @Environment(\.modelContext) var modelContext
  @State private var isInSettings: Bool = false
  @State private var isImportingAudioAndSRT: Bool = false
  @State private var isImportingAudioFromFiles: Bool = false
  @State private var isImportingVideoFromPhotos: Bool = false
  @State private var isImportingYouTube: Bool = false
  @State private var tagEditingItem: ItemEntity?

  private let namespace: Namespace.ID

  private let onSelect: (ItemEntity) -> Void

  init(
    namespace: Namespace.ID,
    service: Service,
    openAIService: OpenAIService?,
    onSelect: @escaping (ItemEntity) -> Void
  ) {
    self.namespace = namespace
    self.service = service
    self.openAIService = openAIService
    self.onSelect = onSelect
  }

  var body: some View {

    CollectionView(layout: .list) {
      if service.hasTranscribingItems {
        let progress = service.transcriptionProgress
        TranscriptionProgressView(
          currentItemTitle: progress.currentItemTitle,
          remainingCount: progress.remainingCount,
          onCancel: {
            service.cancelTranscribe()
          }
        )
      }
      tagList
      allItems
    }
    .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    .overlay {
      if items.isEmpty {
        emptyView()
      }
    }
    .toolbar(content: {
      if isSettingsEnabled {

        ToolbarItem(placement: .topBarLeading) {
          Button {
            isInSettings = true
          } label: {
            Image(systemName: "gearshape")
          }
          .matchedTransitionSource(id: "settings", in: namespace)
        }

      }
      ToolbarItem(placement: .topBarTrailing) {

        Menu {
          Button("File and SRT") {
            isImportingAudioAndSRT = true
          }
          Menu.init(content: {            
            Button("Photos") {
              isImportingVideoFromPhotos = true
            }
            Button("Files") {
              isImportingAudioFromFiles = true
            }
          }, label: {
            Text("From Device")
          })
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
        SettingsView(service: service)
          .navigationTransition(.zoom(sourceID: "settings", in: namespace))
      }
    )
    .modifier(
      ImportModifier(
        isPresented: $isImportingAudioFromFiles,
        service: service
      )
    )
    .modifier(
      PhotosVideoPickerModifier(
        isPresented: $isImportingVideoFromPhotos,
        service: service
      )
    )

  }

  @ViewBuilder
  private var tagList: some View {
    if tags.isEmpty == false {

      Section {

        ForEach(tags) { tag in
          NavigationLink(
            value: tag
          ) {
            ListComponents.Cell {
              HStack {
                Image(systemName: "tag")
                Text(tag.name ?? "")
                  .font(.headline)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.vertical, 10)
              }
            }
            .matchedTransitionSource(id: tag.id, in: namespace)
          }
          .foregroundStyle(.primary)
          .contextMenu {
            Button("Delete", role: .destructive) {
              Task {
                do {
                  try service.deleteTag(tag)
                } catch {
                  Log.error("Failed to delete tag: \(error)")
                }
              }
            }
          }
        }

      } header: {
        ListComponents.Header.init(title: "Tags")
      }
    }
  }

  private var allItems: some View {
    Section {
      ItemListFragment(
        items: items,
        onSelect: onSelect,
        service: service
      )
    } header: {
      ListComponents.Header.init(title: "All Items")
    }
  }

}

struct ItemListFragment: View {

  let items: [ItemEntity]
  let onSelect: (ItemEntity) -> Void
  let service: Service

  init(
    items: [ItemEntity],
    onSelect: @escaping (ItemEntity) -> Void,
    service: Service
  ) {
    self.items = items
    self.onSelect = onSelect
    self.service = service
  }

  var body: some View {
    ForEach(items) { item in
      ListComponents.Cell {
        CellContent(title: item.title)
          .onTapGesture {
            onSelect(item)
          }
          .modifier(ItemEditingModifier(item: item, service: service))
      }
    }
  }
}

private struct CellContent: View {

  let title: String

  var body: some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.headline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 10)
    .contentShape(Rectangle())

  }
}

private struct ItemEditingModifier: ViewModifier {

  @Environment(\.modelContext) var modelContext
  @State private var editingItem: ItemEntity?
  @Query var allTags: [TagEntity]

  private let item: ItemEntity
  private let service: Service

  init(
    item: ItemEntity,
    service: Service
  ) {
    self.item = item
    self.service = service
  }

  func body(content: Content) -> some View {
    content
      .contextMenu(menuItems: {
        Button("Edit") {
          editingItem = item
        }
        Button("Delete", role: .destructive) {
          // TODO: too direct
          modelContext.delete(item)
        }
      })
      .sheet(
        item: $editingItem,
        content: { item in
          EditItemSheet(
            item: item,
            service: service,
            allTags: allTags
          )
          .presentationDetents([.medium, .large])
        }
      )
  }

}

struct ImportModifier: ViewModifier {

  private let audioUTTypes: Set<UTType> = [
    .mp3, .aiff, .wav, .mpeg4Audio,
  ]
  
  private let videoUTTypes: Set<UTType> = [
    .movie, .mpeg4Movie, .quickTimeMovie, .avi
  ]

  private struct Selected: Identifiable {
    let id = UUID()
    let selectingFiles: [TargetFile]
  }

  @Binding var isPresented: Bool
  @State private var selected: Selected?
  private let service: Service
  private let defaultTag: TagEntity?

  init(isPresented: Binding<Bool>, service: Service, defaultTag: TagEntity? = nil) {
    self._isPresented = isPresented
    self.service = service
    self.defaultTag = defaultTag
  }

  func body(content: Content) -> some View {
    content
      .sheet(
        item: $selected,
        content: { selected in
          AudioImportView(
            service: service,
            targets: selected.selectingFiles,
            defaultTag: defaultTag,
            onSubmit: {
              self.selected = nil
            }
          )
        }
      )
      .fileImporter(
        isPresented: $isPresented,
        allowedContentTypes: Array(audioUTTypes.union(videoUTTypes)),
        allowsMultipleSelection: true,
        onCompletion: { result in
          switch result {
          case .success(let urls):

            // find matching audio and video files
            let mediaFiles = Set(
              urls.filter { url in
                let allTypes = audioUTTypes.union(videoUTTypes)
                for type in allTypes {
                  if UTType(filenameExtension: url.pathExtension)?.conforms(to: type) == true {
                    return true
                  }
                }
                return false
              }
            )

            self.selected = Selected(
              selectingFiles: mediaFiles.map { url in
                // Determine file type based on extension
                let isVideo = videoUTTypes.contains { type in
                  UTType(filenameExtension: url.pathExtension)?.conforms(to: type) == true
                }
                
                return TargetFile(
                  name: url.lastPathComponent,
                  url: url,
                  fileType: isVideo ? .video : .audio
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

private struct TranscriptionProgressView: View {
  let currentItemTitle: String?
  let remainingCount: Int
  let onCancel: () -> Void
  
  @Environment(\.scenePhase) var scenePhase

  var body: some View {
    HStack(spacing: 12) {
      ProgressView()
        .scaleEffect(0.8)
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          if let title = currentItemTitle {
            Text("Transcribing: \(title)")
              .font(.subheadline)
              .lineLimit(1)
          }
          if scenePhase == .background {
            Label("Background", systemImage: "moon.fill")
              .font(.caption2)
              .foregroundStyle(.blue)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.blue.opacity(0.15))
              .cornerRadius(4)
          }
        }
        Text("\(remainingCount) remaining")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button(action: onCancel) {
        Image(systemName: "xmark.circle.fill")
          .font(.title2)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }
}
