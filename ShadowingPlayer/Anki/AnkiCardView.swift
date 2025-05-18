import SwiftUI

struct AnkiCardView: View {

  struct BrowserItem: Identifiable {

    var id: String {
      url.absoluteString
    }

    let url: URL
  }

  let front: String
  let back: String
  let tags: [String]
  let speechClient: SpeechClient
  let showingAnswer: Bool
  let onTap: () -> Void

  @State private var browsingItem: BrowserItem?
  @State private var isEditing: Bool = false

  private let dictionarySites = [
    DictionarySite(name: "Thesaurus", url: "https://www.thesaurus.com/browse/"),
    DictionarySite(name: "Dictionary.com", url: "https://www.dictionary.com/browse/"),
  ]

  init(
    item: AnkiModels.ExpressionItem,
    speechClient: SpeechClient,
    showingAnswer: Bool,
    onTap: @escaping () -> Void
  ) {
    self.front = item.front ?? ""
    self.back = item.back ?? ""
    self.tags = item.tags?.compactMap { $0.name } ?? []
    self.speechClient = speechClient
    self.showingAnswer = showingAnswer
    self.onTap = onTap
  }

  init(
    front: String?,
    back: String?,
    tags: [String] = [],
    speechClient: SpeechClient,
    showingAnswer: Bool,
    onTap: @escaping () -> Void
  ) {
    self.front = front ?? ""
    self.back = back ?? ""
    self.tags = tags
    self.speechClient = speechClient
    self.showingAnswer = showingAnswer
    self.onTap = onTap
  }

  private func openDictionary(site: DictionarySite) {
    let encodedWord = front.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
    browsingItem = .init(url: URL(string: site.url + encodedWord)!)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {

      VStack(alignment: .leading) {
        HStack {
          Text(front)
            .font(.largeTitle.bold())
            .textSelection(.enabled)
          Spacer()
          HStack(spacing: 8) {
            Button(action: {
              speechClient.speak(text: front)
            }) {
              Image(systemName: "speaker.wave.2")
                .font(.title)
            }
            .buttonStyle(.bordered)
            Menu {
              ForEach(dictionarySites, id: \.name) { site in
                Button(site.name) {
                  openDictionary(site: site)
                }
              }
            } label: {
              Image(systemName: "book")
                .font(.title)
            }
            .buttonStyle(.bordered)
          }
        }

        if showingAnswer, !back.isEmpty {
          Divider()
          ScrollView {
            Text(back)
              .font(.title2)
              .multilineTextAlignment(.center)
          }
        }
      }

      Spacer()

      if !tags.isEmpty {
        HStack {
          ForEach(tags, id: \.self) { tag in
            Text(tag)
              .padding(4)
              .background(Color.gray.opacity(0.2))
              .cornerRadius(8)
          }
        }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
    .sheet(item: $browsingItem) { item in
      SafariView(url: item.url)
    }
    .toolbar { 
      ToolbarItem(placement: .topBarTrailing) { 
        Button(action: {
          isEditing.toggle()
        }) {
          Image(systemName: "pencil")
        }
      }
    }
  }
}

#Preview {
  @Previewable @State var showingAnswer = false
  AnkiCardView(
    front: "こんにちは",
    back: "Hello",
    tags: [],
    speechClient: .init(),
    showingAnswer: showingAnswer,
    onTap: {
      showingAnswer.toggle()
    }
  )
  .padding()
  .background(Color.gray.opacity(0.1))
}

#Preview("表のみ") {
  AnkiCardView(
    front: "こんにちは",
    back: "Hello",
    tags: [],
    speechClient: .init(),
    showingAnswer: false,
    onTap: {}
  )
  .padding()
  .background(Color.gray.opacity(0.1))
}

#Preview("表＋裏") {
  AnkiCardView(
    front: "こんにちは",
    back: "Hello",
    tags: [],
    speechClient: .init(),
    showingAnswer: true,
    onTap: {}
  )
  .padding()
  .background(Color.gray.opacity(0.1))
}
