import SwiftData
import SwiftUI

struct AnkiView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var books: [AnkiBook]
  @State private var showingJSONImport: Bool = false
  @State private var selectedBook: AnkiBook?

  var body: some View {
    NavigationStack {
      VStack {
        if books.isEmpty {
          ContentUnavailableView {
            Text("No Vocabulary Books")
          } description: {
            Text("Add vocabulary by importing JSON data")
          } actions: {
            Button(action: { showingJSONImport = true }) {
              Text("Import Vocabulary")
                .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
          }
        } else {
          List {
            ForEach(books) { book in
              NavigationLink(destination: AnkiBookDetail(book: book)) {
                HStack {
                  Text(book.name)
                  Spacer()
                  Text("\(book.items.count) items")
                    .foregroundStyle(.secondary)
                }
              }
            }
            .onDelete(perform: deleteBooks)
          }
        }
      }
      .navigationTitle("Vocabulary")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: { showingJSONImport = true }) {
            Label("Import", systemImage: "square.and.arrow.down")
          }
        }
      }
      .sheet(isPresented: $showingJSONImport) {
        AnkiJSONImportView()
      }
    }
  }

  private func deleteBooks(at offsets: IndexSet) {
    for index in offsets {
      let book = books[index]
      modelContext.delete(book)
    }
  }
}

struct AnkiBookDetail: View {
  var book: AnkiBook

  var body: some View {
    List {
      ForEach(book.items) { item in
        NavigationLink(destination: AnkiItemDetail(item: item)) {
          VStack(alignment: .leading) {
            Text(item.input)
              .font(.headline)
            Text(item.meaning)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
      }
    }
    .navigationTitle(book.name)
  }
}

struct AnkiItemDetail: View {
  var item: AnkiItem
  @State private var playingAudio = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading) {
            Text(item.input)
              .font(.largeTitle.bold())

            if !item.ipa.isEmpty {
              Text(item.ipa)
                .font(.title3.monospaced())
                .foregroundStyle(.secondary)
            }
          }

          Spacer()

          Button(action: {
            playingAudio.toggle()
            // Here you could implement text-to-speech functionality
          }) {
            Image(systemName: playingAudio ? "speaker.wave.2.fill" : "speaker.wave.2")
              .font(.title)
          }
          .buttonStyle(.bordered)
        }

        Divider()

        Text(item.meaning)
          .font(.title2)

        if !item.partsOfSpeech.isEmpty {
          Text("**Part of speech:** \(item.partsOfSpeech)")
            .font(.subheadline)
            .padding(.top, 4)
        }

        if !item.synonyms.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Synonyms:")
              .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
              HStack {
                ForEach(item.synonyms, id: \.self) { synonym in
                  Text(synonym)
                    .padding(8)
                    .background(
                      RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
              }
            }
          }
          .padding(.top, 8)
        }

        if !item.sentences.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Example Sentences:")
              .font(.headline)

            ForEach(item.sentences, id: \.self) { sentence in
              Text(sentence)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                )
            }
          }
          .padding(.top, 8)
        }
      }
      .padding()
    }
    .navigationTitle("Vocabulary Detail")
  }
}

// Keep the original AnkiCardView for compatibility
struct AnkiCardView: View {
  // 単純なプロパティでステート管理
  @State private var currentWord = "Example"
  @State private var currentMeaning = "例"
  @State private var currentExample = "This is an example sentence."
  @State private var showingAnswer = false
  @State private var flipAnimation = false
  @State private var currentIndex = 0
  @State private var isReviewCompleted = false

  // テストデータ
  private let words = ["Apple", "Beautiful", "Computer"]
  private let meanings = ["リンゴ", "美しい", "コンピュータ"]
  private let examples = [
    "I ate an apple for breakfast.",
    "The sunset was beautiful.",
    "I bought a new computer.",
  ]

  var body: some View {
    VStack {
      if isReviewCompleted {
        completionView
      } else {
        cardReviewView
      }
    }
    .padding()
    .onAppear {
      updateCurrentCard()
    }
  }

  private var completionView: some View {
    VStack(spacing: 20) {
      Text("レビュー完了！")
        .font(.largeTitle)
        .fontWeight(.bold)

      Text("全てのカードを確認しました。")
        .font(.title2)

      Button("もう一度") {
        currentIndex = 0
        isReviewCompleted = false
        showingAnswer = false
        updateCurrentCard()
      }
      .buttonStyle(.borderedProminent)
      .padding(.top)
    }
  }

  private var cardReviewView: some View {
    VStack {
      // カード番号表示
      Text("\(currentIndex + 1) / \(words.count)")
        .font(.headline)
        .padding()

      Spacer()

      // タップ可能なカード表示部分
      ZStack {
        Rectangle()
          .fill(Color(.systemBackground))
          .cornerRadius(16)
          .shadow(radius: 5)

        VStack(spacing: 20) {
          Text(currentWord)
            .font(.system(size: 38, weight: .bold))
            .multilineTextAlignment(.center)
            .padding(.top)

          if showingAnswer {
            Divider()

            Text(currentMeaning)
              .font(.title2)
              .multilineTextAlignment(.center)

            Text("• \(currentExample)")
              .font(.body)
              .foregroundColor(.secondary)
              .padding(.top, 8)
          }
        }
        .padding()
        .frame(maxWidth: .infinity)
      }
      .frame(height: 300)
      .padding()
      .onTapGesture {
        showingAnswer.toggle()
      }

      Spacer()

      // 難易度選択ボタン（常に表示）
      difficultyButtons
    }
  }

  private var difficultyButtons: some View {
    HStack(spacing: 16) {
      difficultyButton(title: "難しい", color: .red)
      difficultyButton(title: "普通", color: .yellow)
      difficultyButton(title: "簡単", color: .green)
    }
    .padding()
  }

  private func difficultyButton(title: String, color: Color) -> some View {
    Button(action: {
      moveToNextCard()
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

  // ヘルパー関数
  private func updateCurrentCard() {
    guard currentIndex < words.count else {
      isReviewCompleted = true
      return
    }

    currentWord = words[currentIndex]
    currentMeaning = meanings[currentIndex]
    currentExample = examples[currentIndex]
    showingAnswer = false
  }

  private func moveToNextCard() {
    currentIndex += 1
    showingAnswer = false

    if currentIndex >= words.count {
      isReviewCompleted = true
    } else {
      updateCurrentCard()
    }
  }

}

#Preview {
  AnkiView()
    .modelContainer(for: [AnkiBook.self, AnkiItem.self])
}

#Preview("Item Detail") {
  let item = AnkiItem()
  item.input = "apple"
  item.meaning = "りんご（果物の一種）"
  item.partsOfSpeech = "noun"
  item.ipa = "/ˈæpəl/"
  item.synonyms = ["fruit", "pome", "orchard fruit"]
  item.sentences = [
    "I ate a juicy apple for breakfast.",
    "She picked an apple from the tree in the backyard.",
  ]

  return NavigationStack {
    AnkiItemDetail(item: item)
  }
}
