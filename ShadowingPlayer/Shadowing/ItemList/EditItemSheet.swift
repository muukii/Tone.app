import SwiftUI
import SwiftData
import AppService
import UIComponents

struct EditItemSheet: View {
  
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  
  let item: ItemEntity
  let service: Service
  let allTags: [TagEntity]
  
  @State private var title: String
  @State private var selectedTags: Set<TagEntity>
  
  init(
    item: ItemEntity,
    service: Service,
    allTags: [TagEntity]
  ) {
    self.item = item
    self.service = service
    self.allTags = allTags
    self._title = State(initialValue: item.title)
    self._selectedTags = State(initialValue: Set(item.tags))
  }
  
  var body: some View {
    NavigationStack {
      Form {
        Section("Title") {
          TextField("Title", text: $title)
            .autocorrectionDisabled()
        }
        
        Section("Tags") {
          TagEditorInnerView(
            nameKeyPath: \.name,
            currentTags: Array(selectedTags),
            allTags: allTags,
            onAddTag: { tag in
              selectedTags.insert(tag)
            },
            onRemoveTag: { tag in
              selectedTags.remove(tag)
            },
            onCreateTag: { name in
              guard let newTag = try? service.createTag(name: name) else {
                fatalError("Failed to create tag")
              }
              return newTag
            }
          )
        }
      }
      .navigationTitle("Edit Item")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            saveChanges()
            dismiss()
          }
          .fontWeight(.medium)
          .disabled(title.isEmpty)
        }
      }
    }
  }
  
  private func saveChanges() {
    // Update title
    if item.title != title {
      item.title = title
    }
    
    // Update tags
    item.tags = Array(selectedTags)
    
    // Save changes
    do {
      try modelContext.save()
    } catch {
      Log.error("Failed to save item changes: \(error)")
    }
  }
}
