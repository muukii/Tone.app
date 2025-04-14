import SwiftData
import SwiftUI

struct AnkiJSONImportView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var jsonText: String = ""
  @State private var selectedBook: AnkiBook?
  @State private var shouldCreateNewBook: Bool = false
  @State private var newBookName: String = "Imported Vocabulary"
  @State private var importStatus: String?
  @State private var isImporting: Bool = false
  @State private var showErrorAlert: Bool = false
  @State private var errorMessage: String = ""

  @Query private var books: [AnkiBook]

  private let ankiService = AnkiService()

  var body: some View {
    NavigationStack {
      Form {
        Section("JSON Data") {
          TextEditor(text: $jsonText)
            .frame(minHeight: 200)
            .monospaced()
          Button("Paste Example", action: pasteExample)
            .buttonStyle(.bordered)
        }

        Section("Target Book") {
          Picker("Import to", selection: $shouldCreateNewBook) {
            Text("New Book").tag(true)
            Text("Existing Book").tag(false)
          }
          .pickerStyle(.segmented)

          if shouldCreateNewBook {
            TextField("New book name", text: $newBookName)
          } else if !books.isEmpty {
            Picker("Select Book", selection: $selectedBook) {
              Text("Select a book").tag(nil as AnkiBook?)
              ForEach(books) { book in
                Text(book.name).tag(book as AnkiBook?)
              }
            }
          } else {
            Text("No existing books available")
              .foregroundColor(.secondary)
          }
        }

        if let status = importStatus {
          Section {
            Text(status)
              .foregroundColor(.green)
          }
        }
      }
      .navigationTitle("Import Vocabulary")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: importJSON) {
            if isImporting {
              ProgressView()
            } else {
              Text("Import")
            }
          }
          .disabled(
            isImporting || jsonText.isEmpty
              || (!shouldCreateNewBook && selectedBook == nil && !books.isEmpty))
        }
      }
      .alert("Import Error", isPresented: $showErrorAlert) {
        Button("OK") { showErrorAlert = false }
      } message: {
        Text(errorMessage)
      }
    }
  }

  private func pasteExample() {
    jsonText = """
      [
        {
          "input": "apple",
          "meaning": "りんご（果物の一種）",
          "partsOfSpeech": "noun",
          "ipa": "/ˈæpəl/",
          "synonyms": ["fruit", "pome", "orchard fruit", "red fruit", "green fruit"],
          "sentences": [
            "I ate a juicy apple for breakfast.",
            "She picked an apple from the tree in the backyard.",
            "He packed an apple in his lunchbox."
          ]
        },
        {
          "input": "sensible",
          "meaning": "分別のある、賢明な",
          "partsOfSpeech": "adjective",
          "ipa": "/ˈsɛnsəbəl/",
          "synonyms": ["reasonable", "prudent", "wise", "rational", "logical"],
          "sentences": [
            "It was sensible of you to bring an umbrella.",
            "She's a very sensible person who always thinks before she acts.",
            "Wearing a helmet while cycling is a sensible decision."
          ]
        }
      ]
      """
  }

  private func importJSON() {
    guard !jsonText.isEmpty else { return }

    isImporting = true
    
    defer {
      isImporting = false
    }
    
    do {
        
        do {
          guard let jsonData = jsonText.data(using: .utf8) else {
            throw NSError(
              domain: "JSONImport", code: 1,
              userInfo: [NSLocalizedDescriptionKey: "Could not convert text to data"])
          }
                    
          let count = try ankiService.importFromJSON(
            jsonData
          )
          
          importStatus = "Successfully imported \(count) vocabulary items"
          
          // Reset form after successful import
          if shouldCreateNewBook {
            newBookName = "Imported Vocabulary"
          }
        } catch {
          errorMessage = "Import failed: \(error.localizedDescription)"
          showErrorAlert = true
        }
    } catch {
      print("Transaction failed: \(error)")
    }
    
  }
}

#Preview {
  AnkiJSONImportView()
    .modelContainer(for: [AnkiBook.self, AnkiItem.self])
}
