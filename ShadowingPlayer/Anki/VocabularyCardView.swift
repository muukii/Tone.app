import SafariServices
import SwiftUI

struct SelectableText: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .textSelection(.enabled)
  }
}

struct DictionarySite {
  let name: String
  let url: String
}

struct VocabularyCardView: View {

  struct BrowserItem: Identifiable {

    var id: String {
      url.absoluteString
    }

    let url: URL
  }

  let front: String
  let back: String

  let speechClient: SpeechClient

  @State private var browsingItem: BrowserItem?

  private let dictionarySites = [
    DictionarySite(name: "Thesaurus", url: "https://www.thesaurus.com/browse/"),
    DictionarySite(name: "Dictionary.com", url: "https://www.dictionary.com/browse/"),
  ]

  init(item: AnkiModels.ExpressionItem, speechClient: SpeechClient) {
    self.front = item.front
    self.back = item.back
    self.speechClient = speechClient
  }

  private func openDictionary(site: DictionarySite) {
    let encodedWord = front.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
    browsingItem = .init(url: URL(string: site.url + encodedWord)!)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading) {
            SelectableText(front)
              .font(.largeTitle.bold())

            if !back.isEmpty {
              Text(back)
                .font(.title3.monospaced())
                .foregroundStyle(.secondary)
            }
          }

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

        Divider()

        Text(back)
          .font(.title2)      
      }
      .padding()
    }
    .sheet(item: $browsingItem) { item in
      SafariView(url: item.url)
    }
  }
}

struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: Context) -> SFSafariViewController {
    SFSafariViewController(url: url)
  }

  func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
