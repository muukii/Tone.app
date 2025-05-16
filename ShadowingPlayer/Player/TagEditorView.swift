import SwiftUI
import SwiftData
import AppService

struct TagEditorView<Tag: TagType>: View {
  
  private var tags: [Tag]

  @State private var newTagText: String = ""

  private var allTags: [Tag]
    
  private let onAddTag: (Tag) -> Void
  private let onRemoveTag: (Tag) -> Void
  
  @Environment(\.modelContext) private var modelContext

  init(
    currentTags: [Tag],
    allTags: [Tag],
    onAddTag: @escaping (Tag) -> Void,
    onRemoveTag: @escaping (Tag) -> Void
  ) {
    self.tags = currentTags
    self.allTags = allTags
    self.onAddTag = onAddTag
    self.onRemoveTag = onRemoveTag
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 12) {
        List {
          ForEach(tags, id: \.name) { tag in
            HStack {
              Text(tag.name)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
              Spacer()
              Button(role: .destructive) {
                onRemoveTag(tag)
              } label: {
                Image(systemName: "trash")
              }
            }
          }
        }
        .listStyle(.automatic)
          
        VStack {
          suggestionView
          
          inputView
        }
        .padding(.horizontal)
        
      }      
      .navigationTitle("Tags")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
  
  @ViewBuilder
  private var suggestionView: some View {
    if !newTagText.isEmpty {
      let filtered = allTags.filter { tag in
        tag.name.localizedCaseInsensitiveContains(newTagText) &&
        !tags.contains(where: { $0.name == tag.name })
      }
      if !filtered.isEmpty {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(filtered, id: \.name) { tag in
            Button {
              onAddTag(tag)
              newTagText = ""
            } label: {
              Text(tag.name)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
          }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
        .padding(.horizontal, 8)
      }
    }
  }
  
  private var inputView: some View {
    HStack {      
      TextField("Set tag", text: $newTagText)
        .padding(.horizontal, 4)
      Button("Add") {
        
        let tag = fetchTag(for: newTagText)
        
        onAddTag(tag)
        
        newTagText = ""
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(white: 0.5, opacity: 0.1))
    )
  }
  
  private func fetchTag(for name: String) -> Tag {
    
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    
    let currentTag = allTags.first { $0.name == trimmed }
    
    guard let currentTag else {
      
      let newTag = Tag(name: trimmed)
      modelContext.insert(newTag)
      newTag.markAsUsed()
      return newTag
    }
    
    return currentTag
  }
  
}

