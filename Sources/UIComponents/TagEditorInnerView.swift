import SwiftUI

public struct TagEditorInnerView<Tag: Identifiable>: View {
  
  private var tags: [Tag]
  
  @State private var newTagText: String = ""
  
  private var allTags: [Tag]
  
  private let onAddTag: (Tag) -> Void
  private let onRemoveTag: (Tag) -> Void
  private let onCreateTag: (String) -> Tag
  private let nameKeyPath: KeyPath<Tag, String?>
  
  public init(
    nameKeyPath: KeyPath<Tag, String?>,
    currentTags: [Tag],
    allTags: [Tag],
    onAddTag: @escaping (Tag) -> Void,
    onRemoveTag: @escaping (Tag) -> Void,
    onCreateTag: @escaping (String) -> Tag
  ) {
    self.tags = currentTags
    self.allTags = allTags
    self.nameKeyPath = nameKeyPath
    self.onAddTag = onAddTag
    self.onRemoveTag = onRemoveTag
    self.onCreateTag = onCreateTag
  }
  
  public var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 12) {
        List {
          ForEach(tags) { tag in
            if let name = tag[keyPath: nameKeyPath] {
              HStack {
                Text(name)
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
        tag[keyPath: nameKeyPath]?.localizedCaseInsensitiveContains(newTagText) == true &&
        !tags.contains(where: { $0[keyPath: nameKeyPath] == tag[keyPath: nameKeyPath] })
      }
      if !filtered.isEmpty {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(filtered) { tag in
            if let name = tag[keyPath: nameKeyPath] {
              Button {
                onAddTag(tag)
                newTagText = ""
              } label: {
                Text(name)
                  .padding(.vertical, 4)
                  .padding(.horizontal, 8)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.plain)
            }
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
        
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let existingTag = allTags.first(where: { $0[keyPath: nameKeyPath] == trimmed }) {
          onAddTag(existingTag)
        } else {
          let newTag = onCreateTag(trimmed)
          onAddTag(newTag)
        }
        
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
  
}


#if DEBUG
import SwiftData

@Model
private final class MockTag {
  
  var name: String?
  var lastUsedAt: Date?
  
  init(name: String) {
    self.name = name
  }
  
  func markAsUsed() {
    lastUsedAt = Date()
  }
}

#Preview {
    
  @Previewable @State var currentTags: [MockTag] = [
    MockTag(name: "Japanese"),
    MockTag(name: "English")
  ]
  
  @Previewable @State var allTags: [MockTag] = [
    MockTag(name: "Japanese"),
    MockTag(name: "English"),
    MockTag(name: "Spanish"),
    MockTag(name: "French"),
    MockTag(name: "German")
  ]
  
  return TagEditorInnerView(
    nameKeyPath: \.name,
    currentTags: currentTags,
    allTags: allTags,
    onAddTag: { tag in
      if !currentTags.contains(where: { $0.name == tag.name }) {
        currentTags.append(tag)
      }
    },
    onRemoveTag: { tag in
      currentTags.removeAll { $0.name == tag.name }
    },
    onCreateTag: { name in
      let newTag = MockTag(name: name)
      allTags.append(newTag)
      return newTag
    }
  )
}
#endif
