import SwiftUI
import SafariServices

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
  
  let input: String
  let meaning: String
  let ipa: String
  let partsOfSpeech: String
  let synonyms: [String]
  let sentences: [String]
  
  let speechClient: SpeechClient
  
  @State private var browsingItem: BrowserItem?
  
  private let dictionarySites = [
    DictionarySite(name: "Thesaurus", url: "https://www.thesaurus.com/browse/"),
    DictionarySite(name: "Dictionary.com", url: "https://www.dictionary.com/browse/")
  ]
  
  private func openDictionary(site: DictionarySite) {
    let encodedWord = input.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
    browsingItem = .init(url: URL(string: site.url + encodedWord)!)
  }
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading) {
            SelectableText(input)
              .font(.largeTitle.bold())
            
            if !ipa.isEmpty {
              Text(ipa)
                .font(.title3.monospaced())
                .foregroundStyle(.secondary)
            }
          }
          
          Spacer()
          
          HStack(spacing: 8) {
            Button(action: {            
              speechClient.speak(text: input)
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
        
        Text(meaning)
          .font(.title2)
        
        if !partsOfSpeech.isEmpty {
          Text(partsOfSpeech)
            .font(.subheadline)
            .padding(.top, 4)
        }
        
        if !synonyms.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Synonyms:")
              .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
              HStack {
                ForEach(synonyms, id: \.self) { synonym in
                  Text(synonym)
                    .padding(8)
                    .background(
                      RoundedRectangle(cornerRadius: 8)
                        .fill(.primary.opacity(0.1))
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: 8)
                        .inset(by: 1)
                        .stroke(.primary.opacity(0.3), lineWidth: 2)
                    )
                }
              }
              .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, 16, for: .automatic)
            .padding(.horizontal, -16)
          }
          .padding(.top, 8)
        }
        
        if !sentences.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Example Sentences:")
              .font(.headline)
            
            ForEach(sentences, id: \.self) { sentence in
              Text(sentence)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(.thinMaterial)
                )
            }
          }
          .padding(.top, 8)
        }
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

#Preview("Vocabulary Card") {
  NavigationStack {
    VocabularyCardView(
      input: "water",
      meaning: "りんご（果物の一種）",
      ipa: "/ˈæpəl/",
      partsOfSpeech: "noun",
      synonyms: ["fruit", "pome", "orchard fruit"],
      sentences: [
        "I ate a juicy apple for breakfast.",
        "She picked an apple from the tree in the backyard.",
      ],
      speechClient: .init()
    )
  }
}

