import SafariServices
import SwiftData
import SwiftUI

struct AnkiCardStackView: View {

  @Environment(\.modelContext) private var modelContext

  let reviewItems: [AnkiModels.ExpressionItem]
  let service: AnkiService
  @State private var currentIndex = 0
  @State private var showingAnswer = false
  @State private var isReviewCompleted = false
  @State private var errorMessage: String? = nil
  @ObjectEdge var speechClient: SpeechClient = .init()

  init(
    items: [AnkiModels.ExpressionItem],
    service: AnkiService
  ) {
    self.reviewItems = items
    self.service = service
  }

  var body: some View {
    VStack {
      if let errorMessage {
        Text(errorMessage)
          .foregroundColor(.red)
      } else if isReviewCompleted {
        completionView
      } else if !reviewItems.isEmpty {
        cardReviewView
      } else {
        Text("本日レビューすべきカードはありません")
          .font(.title2)
          .foregroundColor(.secondary)
      }
    }
    .padding()
  }

  private var completionView: some View {
    VStack(spacing: 20) {
      Text("レビュー完了！")
        .font(.largeTitle)
        .fontWeight(.bold)
      Text("全てのカードを確認しました。")
        .font(.title2)
        .buttonStyle(.borderedProminent)
        .padding(.top)
    }
  }

  private var cardReviewView: some View {
    let item = reviewItems[currentIndex]
    return VStack {
      // 進捗表示
      Text("\(currentIndex + 1) / \(reviewItems.count)")
        .font(.headline)
        .padding()
      Spacer()
      // カード表示
      AnkiCardView(
        front: item.front,
        back: item.back,
        tags: item.tags?.compactMap { $0.name } ?? [],
        speechClient: speechClient,
        showingAnswer: showingAnswer,
        onTap: { showingAnswer.toggle() }
      )
      .frame(maxHeight: .infinity)
      // 3択ボタン
      difficultyButtons
    }
  }

  private var difficultyButtons: some View {
    HStack(spacing: 16) {
      difficultyButton(title: "難しい", color: .red, grade: .again)
      difficultyButton(title: "普通", color: .yellow, grade: .hard)
      difficultyButton(title: "簡単", color: .green, grade: .easy)
    }
    .padding()
  }

  private func difficultyButton(title: String, color: Color, grade: AnkiModels.ReviewGrade)
    -> some View
  {
    Button(action: {
      answer(grade)
    }) {
      VStack {
        Text(title)
          .font(.headline)
          .padding()
          .frame(maxWidth: .infinity)
          .background(color.opacity(0.2))
          .foregroundColor(color)
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(color, lineWidth: 2)
          )
      }
    }
  }

  private func answer(_ grade: AnkiModels.ReviewGrade) {
    let item = reviewItems[currentIndex]
    service.answer(grade: grade, for: item)
    moveToNextCard()
  }

  private func moveToNextCard() {
    currentIndex += 1
    showingAnswer = false
    if currentIndex >= reviewItems.count {
      isReviewCompleted = true
    }
  }
}

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
