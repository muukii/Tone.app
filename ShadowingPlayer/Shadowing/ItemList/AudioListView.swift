import AppService
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import CollectionView

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
  @State private var isImportingAudio: Bool = false
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
          }
          .foregroundStyle(.primary)
          .matchedTransitionSource(id: tag, in: namespace)
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

  var body: some View {
    Group {
      
      CollectionView(layout: .list) { 
        tagList
        allItems
      }     
      .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
      .safeAreaPadding(.bottom, 50)
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
            .navigationTransition(.zoom(sourceID: "settings", in: namespace))
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

struct AudioListInTagView: View {

  @Query private var items: [ItemEntity]
  private let service: Service
  private let onSelect: (ItemEntity) -> Void
  private let tag: TagEntity
  
  @State private var isRenaming = false
  @State private var newTagName = ""
  @State private var isProcessingRename = false

  init(
    service: Service,
    tag: TagEntity,
    onSelect: @escaping (ItemEntity) -> Void
  ) {

    self.service = service
    self.onSelect = onSelect

    let tagName = tag.name

    self._items = Query(
      filter: #Predicate<ItemEntity> {
        $0.tags.contains(where: { $0.name == tagName })
      }
    )

    self.tag = tag

  }

  var body: some View {
    CollectionView(layout: .list) { 
      ItemListFragment(
        items: items,
        onSelect: onSelect,
        service: service
      )
    }
    .navigationTitle(tag.name ?? "")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          newTagName = tag.name ?? ""
          isRenaming = true
        } label: {
          Text("Rename")
//          Image(systemName: "pencil")
//            .resizable()
//            .aspectRatio(contentMode: .fit)
//            .frame(width: 20, height: 20)
        }
        .disabled(isProcessingRename)
      }
    }
    .alert("Rename Tag", isPresented: $isRenaming) {
      TextField("Tag name", text: $newTagName)
      Button("Cancel", role: .cancel) {
        isRenaming = false
      }
      Button("Rename") {
        Task {
          isProcessingRename = true
          defer { isProcessingRename = false }
          
          do {
            try await service.renameTag(tag: tag, newName: newTagName)
          } catch {
            Log.error("Failed to rename tag: \(error)")
          }
        }
        isRenaming = false
      }
    }
  }
}

private struct ItemListFragment: View {

  let items: [ItemEntity]
  let onSelect: (ItemEntity) -> Void
  let service: Service?

  init(items: [ItemEntity], onSelect: @escaping (ItemEntity) -> Void, service: Service? = nil) {
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
  @State private var tagEditingItem: ItemEntity?
  @Query var allTags: [TagEntity]

  private let item: ItemEntity
  private let service: Service?

  init(item: ItemEntity, service: Service? = nil) {
    self.item = item
    self.service = service
  }

  func body(content: Content) -> some View {
    content
      .contextMenu(menuItems: {
        Button("Delete", role: .destructive) {
          // TODO: too direct
          modelContext.delete(item)
        }
        Button("Tags") {
          tagEditingItem = item
        }
      })
      .sheet(
        item: $tagEditingItem,
        content: { item in
          TagEditorView(
            service: service ?? Service(),
            currentTags: item.tags,
            allTags: allTags,
            onAddTag: { tag in
              item.tags.append(tag)
            },
            onRemoveTag: { tag in
              item.tags.removeAll(where: { $0 == tag })
            }
          )
        }
      )
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
