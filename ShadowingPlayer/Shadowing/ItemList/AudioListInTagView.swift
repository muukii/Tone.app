import AppService
import CollectionView
import SwiftData
import SwiftUI

struct AudioListInTagView: View {
  
  @Query private var items: [ItemEntity]
  private let service: Service
  private let onSelect: (ItemEntity) -> Void
  private let tag: TagEntity
  
  @State private var isRenaming = false
  @State private var newTagName = ""
  @State private var isProcessingRename = false
  @State private var activeImportType: ImportType?
  
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
              activeImportType = .audioAndSRT
            } label: {
              Text("File and SRT")
            }
            
            Menu {
              Button {
                activeImportType = .videoFromPhotos
              } label: {
                Text("Photos")
              }
              Button {
                activeImportType = .audioFromFiles
              } label: {
                Text("Files")
              }
            } label: {
              Label("From Device", systemImage: "iphone")
            }
            
            Button {
              activeImportType = .youTube
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
    .sheet(item: $activeImportType) { importType in
      switch importType {
      case .audioAndSRT:
        AudioAndSubtitleImportView(
          service: service,
          defaultTag: tag,
          onComplete: {
            activeImportType = nil
          },
          onCancel: {
            activeImportType = nil
          }
        )
      case .youTube:
        YouTubeImportView(
          service: service,
          defaultTag: tag,
          onComplete: {
            activeImportType = nil
          }
        )
      case .audioFromFiles:
        AudioImportViewWrapper(
          service: service,
          defaultTag: tag,
          onDismiss: {
            activeImportType = nil
          }
        )
      case .videoFromPhotos:
        PhotosVideoPickerViewWrapper(
          service: service,
          defaultTag: tag,
          onDismiss: {
            activeImportType = nil
          }
        )
      }
    }
  }
}