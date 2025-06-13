import SwiftUI
import SwiftData
import AppService
import UIComponents

struct TagEditorView<Tag: TagType>: View {
  
  private var tags: [Tag]
  private var allTags: [Tag]
  private let onAddTag: (Tag) -> Void
  private let onRemoveTag: (Tag) -> Void
  private let service: Service
  
  init(
    service: Service,
    currentTags: [Tag],
    allTags: [Tag],
    onAddTag: @escaping (Tag) -> Void,
    onRemoveTag: @escaping (Tag) -> Void
  ) {
    self.service = service
    self.tags = currentTags
    self.allTags = allTags
    self.onAddTag = onAddTag
    self.onRemoveTag = onRemoveTag
  }
  
  var body: some View {
    TagEditorInnerView(
      nameKeyPath: \.name,
      currentTags: tags,
      allTags: allTags,
      onAddTag: onAddTag,
      onRemoveTag: onRemoveTag,
      onCreateTag: { name in        
        try! service.createTag(name: name) as! Tag
      }
    )
  }
}

struct Previews_TagEditorView_LibraryContent: LibraryContentProvider {
  var views: [LibraryItem] {
    LibraryItem(/*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/)
  }
}
