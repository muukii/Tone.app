import SwiftUI

struct VocabularyDraft {
  var front: String
  var back: String
}
  
struct VocabularyAddView: View {
  
  @State private var frontText: String = ""
  @State private var backText: String = ""
  
  @FocusState private var isFocusedFront: Bool
  @FocusState private var isFocusedBack: Bool
  
  let onSave: (VocabularyDraft) -> Void
  let onCancel: () -> Void
  
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
      }
      .navigationTitle("Add cards")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onCancel()
          }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            onSave(VocabularyDraft(front: frontText, back: backText))
          }
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
  VocabularyAddView(
    onSave: { _ in },
    onCancel: {}
  )
}
