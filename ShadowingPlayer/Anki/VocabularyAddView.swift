import SwiftUI
import SwiftData

struct VocabularyDraft {
  var front: String
  var back: String
  var tags: Set<AnkiModels.Tag> = []
}

struct VocabularyEditView: View {

  @State private var frontText: String
  @State private var backText: String
  @State private var isSelectingTag: Bool = false

  @FocusState private var isFocusedFront: Bool
  @FocusState private var isFocusedBack: Bool

  let itemToEdit: AnkiModels.ExpressionItem?
  let onSave: (VocabularyDraft) -> Void
  let onCancel: () -> Void

  @Query var allTags: [AnkiModels.Tag]
  @State var tags: Set<AnkiModels.Tag>

  init(
    item: AnkiModels.ExpressionItem? = nil,
    onSave: @escaping (VocabularyDraft) -> Void,
    onCancel: @escaping () -> Void
  ) {

    if let item {
      self.tags = .init(item.tags)
    } else {
      self.tags = []
    }

    self.itemToEdit = item
    _frontText = State(initialValue: item?.front ?? "")
    _backText = State(initialValue: item?.back ?? "")
    self.onSave = onSave
    self.onCancel = onCancel
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          PlaceholderTextEditor(placeholder: "Front", text: $frontText)
            .font(.system(size: 24, weight: .bold))
            .frame(height: 100)
            .focused($isFocusedFront)
        }

        Section {
          PlaceholderTextEditor(placeholder: "Back", text: $backText)
            .font(.system(size: 24, weight: .bold))
            .frame(height: 100)
            .focused($isFocusedBack)
        }

        HStack {
          Button("Tag") {
            isSelectingTag = true           
          }
        }
      }
      .navigationTitle(itemToEdit == nil ? "Add cards" : "Edit card")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $isSelectingTag) {
        TagEditorView(
          currentTags: tags.sorted { $0.name < $1.name },
          allTags: allTags,
          onAddTag: { tag in
            tags.insert(tag)
          },
          onRemoveTag: { tag in
            tags.remove(tag)
          }
        )
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onCancel()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(itemToEdit == nil ? "Add" : "Save") {
            onSave(VocabularyDraft(front: frontText, back: backText, tags: tags))
          }
          .disabled(frontText.isEmpty || backText.isEmpty)
        }
      }
      .onAppear {
        isFocusedFront = true
      }
    }
    .interactiveDismissDisabled(!frontText.isEmpty || !backText.isEmpty)
  }
}

#Preview {
  VocabularyEditView(
    onSave: { _ in },
    onCancel: {}
  )
}
