import SwiftUI

public struct TagEditorInnerView<Tag: Identifiable>: View {

  private var tags: [Tag]

  @State private var newTagText: String = ""
  @State private var searchText: String = ""
  @FocusState private var isSearchFocused: Bool

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

  private var availableTags: [Tag] {
    allTags.filter { tag in
      !tags.contains(where: { $0[keyPath: nameKeyPath] == tag[keyPath: nameKeyPath] })
    }
  }

  private var filteredAvailableTags: [Tag] {
    if searchText.isEmpty {
      return availableTags
    }
    return availableTags.filter { tag in
      tag[keyPath: nameKeyPath]?.localizedCaseInsensitiveContains(searchText) == true
    }
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        currentTagsSection

        searchSection

        if !newTagText.isEmpty {
          createNewTagSection
        }

        availableTagsSection
      }
      .padding()
    }
    .navigationTitle("Tags")
    .navigationBarTitleDisplayMode(.inline)
    .scrollDismissesKeyboard(.interactively)
  }

  @ViewBuilder
  private var currentTagsSection: some View {
    if !tags.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Text("Current Tags")
          .font(.headline)
          .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          ForEach(tags) { tag in
            if let name = tag[keyPath: nameKeyPath] {
              TagRow(
                title: name,
                isSelected: true,
                onTap: {},
                onDelete: {
                  withAnimation(.easeInOut(duration: 0.2)) {
                    onRemoveTag(tag)
                  }
                }
              )
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var searchSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Add Tags")
        .font(.headline)
        .foregroundColor(.secondary)

      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.secondary)

        TextField("Search or create tag", text: $newTagText)
          .textFieldStyle(.plain)
          .focused($isSearchFocused)
          .onSubmit {
            if !newTagText.isEmpty {
              createNewTag()
            }
          }

        if !newTagText.isEmpty {
          Button {
            newTagText = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
          }
        }
      }
      .padding(12)
      .background(Color(.systemGray6))
      .cornerRadius(10)
    }
  }

  @ViewBuilder
  private var createNewTagSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if !existingTagMatches {
        Button {
          createNewTag()
        } label: {
          HStack {
            Image(systemName: "plus.circle.fill")
              .foregroundColor(.accentColor)
            Text("Create \"\(newTagText)\"")
              .foregroundColor(.primary)
            Spacer()
          }
          .padding(12)
          .background(Color(.systemGray6))
          .cornerRadius(10)
        }
        .buttonStyle(.plain)
      }
    }
  }

  @ViewBuilder
  private var availableTagsSection: some View {
    let filtered = filteredAvailableTags
    if !filtered.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Text("Available Tags")
          .font(.headline)
          .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          ForEach(filtered) { tag in
            if let name = tag[keyPath: nameKeyPath] {
              TagRow(
                title: name,
                isSelected: false,
                onTap: {
                  withAnimation(.easeInOut(duration: 0.2)) {
                    onAddTag(tag)
                    newTagText = ""
                  }
                },
                onDelete: nil
              )
            }
          }
        }
      }
    }
  }

  private var existingTagMatches: Bool {
    let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
    return allTags.contains { $0[keyPath: nameKeyPath] == trimmed }
  }

  private func createNewTag() {
    let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    if let existingTag = allTags.first(where: { $0[keyPath: nameKeyPath] == trimmed }) {
      onAddTag(existingTag)
    } else {
      let newTag = onCreateTag(trimmed)
      onAddTag(newTag)
    }

    newTagText = ""
  }
}

struct TagRow: View {
  let title: String
  let isSelected: Bool
  let onTap: () -> Void
  let onDelete: (() -> Void)?

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 16, weight: isSelected ? .medium : .regular))
        .foregroundColor(isSelected ? .accentColor : .primary)

      Spacer()

      if isSelected {
        if let onDelete = onDelete {
          Button {
            onDelete()
          } label: {
            Image(systemName: "minus.circle.fill")
              .font(.system(size: 20))
              .foregroundColor(.red)
          }
        }
      } else {
        Image(systemName: "plus.circle")
          .font(.system(size: 20))
          .foregroundColor(.accentColor)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color(.systemGray6))
    )
    .onTapGesture {
      if !isSelected {
        onTap()
      }
    }
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
      MockTag(name: "English"),
    ]

    @Previewable @State var allTags: [MockTag] = [
      MockTag(name: "Japanese"),
      MockTag(name: "English"),
      MockTag(name: "Spanish"),
      MockTag(name: "French"),
      MockTag(name: "German"),
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
