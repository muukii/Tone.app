import AppService
import CollectionView
import SwiftData
import SwiftUI

struct AudioListInTagView: View {
  
  @Query private var items: [ItemEntity]
  private let service: Service
  private let onSelect: (ItemEntity) -> Void
  private let tag: TagEntity
  
  private let namespace: Namespace.ID
  @State private var isRenaming = false
  @State private var newTagName = ""
  @State private var isProcessingRename = false
  @State private var isImportingAudioAndSRT = false
  @State private var isImportingAudioFromFiles = false
  @State private var isImportingVideoFromPhotos = false
  @State private var isImportingYouTube = false
  
  init(
    namespace: Namespace.ID,
    service: Service,
    tag: TagEntity,
    onSelect: @escaping (ItemEntity) -> Void
  ) {
    
    self.namespace = namespace
    self.service = service
    self.onSelect = onSelect
    
    let tagName = tag.name
    
    self._items = Query(
      filter: #Predicate<ItemEntity> {
        $0.tags.contains(where: { $0.name == tagName })
      },
      sort: \.title
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
    .navigationTransition(.zoom(sourceID: tag.id, in: namespace))
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button {
            newTagName = tag.name ?? ""
            isRenaming = true
          } label: {
            Label("Rename", systemImage: "pencil")
          }
          .disabled(isProcessingRename)
          
          Divider()
          
          Menu {
            Button {
              isImportingAudioAndSRT = true
            } label: {
              Text("File and SRT")
            }
            
            Menu {
              Button {
                isImportingVideoFromPhotos = true
              } label: {
                Text("Photos")
              }
              Button {
                isImportingAudioFromFiles = true
              } label: {
                Text("Files")
              }
            } label: {
              Label("From Device", systemImage: "iphone")
            }
            
            Button {
              isImportingYouTube = true
            } label: {
              Text("YouTube (on-device transcribing)")
            }
          } label: {
            Label("Import", systemImage: "square.and.arrow.down")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
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
    .sheet(
      isPresented: $isImportingAudioAndSRT,
      content: {
        AudioAndSubtitleImportView(
          service: service,
          defaultTag: tag,
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
          defaultTag: tag,
          onComplete: {
            isImportingYouTube = false
          }
        )
      }
    )
    .modifier(
      ImportModifier(
        isPresented: $isImportingAudioFromFiles,
        service: service,
        defaultTag: tag
      )
    )
    .modifier(
      PhotosVideoPickerModifier(
        isPresented: $isImportingVideoFromPhotos,
        service: service,
        defaultTag: tag
      )
    )
  }
}
