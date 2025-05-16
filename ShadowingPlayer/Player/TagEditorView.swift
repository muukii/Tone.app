import SwiftUI
import SwiftData
import AppService

struct TagEditorView<Target: TaggedItem>: View {
  
  let item: Target

  private var tags: [TagEntity] {
    item.tags.sorted { $0.name < $1.name }
  }

  @State private var newTagText: String = ""

  @Query var allTags: [TagEntity]
  
  @Environment(\.modelContext) private var modelContext

  init(item: Target) {
    self.item = item
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
                item.tags.removeAll {
                  $0 === tag
                }
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
        !item.tags.contains(where: { $0.name == tag.name })
      }
      if !filtered.isEmpty {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(filtered, id: \.name) { tag in
            Button {
              item.tags.append(tag)
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
        addTag(rawText: newTagText)
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
  
  private func addTag(rawText: String) {
    
    let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    
    do {
      
      let tags = try modelContext.fetch(.init(predicate: #Predicate<TagEntity> { $0.name == trimmed }))            
      
      if tags.isEmpty {
        let newTag = TagEntity(name: trimmed)
        modelContext.insert(newTag)
        newTag.markAsUsed()
        item.tags.append(newTag)
      } else {
        
        assert(tags.count == 1)
        
        let tag = tags.first!
        
        if item.tags.contains(where: { $0 === tag }) {
          return
        }
        
        tag.markAsUsed()
        item.tags.append(tag)
      }
      
    } catch {
      assertionFailure("Failed to fetch tags: \(error)")
    }
  }
}

