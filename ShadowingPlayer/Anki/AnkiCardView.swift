import AVFoundation
import AppService
import SwiftData
import SwiftUI

struct AnkiView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \AnkiModels.Tag.name) private var tags: [AnkiModels.Tag]
  @Query(sort: \AnkiModels.ExpressionItem.front) private var allItems: [AnkiModels.ExpressionItem]
  @State private var showingAddView: Bool = false

  var body: some View {
    NavigationStack {
      List {
        if tags.isEmpty == false {
          
          // Tagごとのセクション
          Section(header: Text("Tags")) {
            ForEach(tags) { tag in
              NavigationLink(value: tag) {
                Text(tag.name)
              }
            }
          }
        }
        // Allセクション
        Section(header: Text("All")) {
          ForEach(allItems) { item in
            NavigationLink(value: item) {
              Text(item.front)
            }
          }
        }

      }
      .navigationTitle("Vocabulary")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: { showingAddView = true }) {
            Label("新しい表現を追加", systemImage: "plus")
          }
        }
      }
      .sheet(isPresented: $showingAddView) {
        VocabularyAddView { draft in
          let newItem = AnkiModels.ExpressionItem(front: draft.front, back: draft.back)
          modelContext.insert(newItem)
          showingAddView = false
        } onCancel: {
          showingAddView = false
        }
      }
      .navigationDestination(
        for: AnkiModels.ExpressionItem.self,
        destination: { item in
          ExpressionDetail(item: item, speechClient: SpeechClient())
        })
    }
  }
}

final class SpeechClient {

  private let synthesizer = AVSpeechSynthesizer()

  func speak(text: String) {
    synthesizer.stopSpeaking(at: .immediate)

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = 0.5
    utterance.pitchMultiplier = 1.0
    synthesizer.speak(utterance)
  }
}

struct ExpressionDetail: View {
  var item: AnkiModels.ExpressionItem
  let speechClient: SpeechClient

  var body: some View {
    VocabularyCardView(
      item: item,
      speechClient: speechClient
    )
    .navigationTitle("Vocabulary Detail")
  }
}

struct AnkiCardView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var reviewItems: [AnkiModels.ExpressionItem] = []
  @State private var currentIndex = 0
  @State private var showingAnswer = false
  @State private var isReviewCompleted = false
  @State private var errorMessage: String? = nil

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
    .onAppear {
      loadReviewItems()
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
        loadReviewItems()
      }
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
      ZStack {
        Rectangle()
          .fill(Color(.systemBackground))
          .cornerRadius(16)
          .shadow(radius: 5)
        VStack(spacing: 20) {
          Text(item.front)
            .font(.system(size: 38, weight: .bold))
            .multilineTextAlignment(.center)
            .padding(.top)
          if showingAnswer {
            Divider()
            Text(item.back)
              .font(.title2)
              .multilineTextAlignment(.center)
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

  private func difficultyButton(title: String, color: Color, grade: AnkiModels.ReviewGrade) -> some View {
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

  private func loadReviewItems() {
    do {
      reviewItems = try AnkiModels.ExpressionItem.fetchItemsToReviewToday(context: modelContext)
      currentIndex = 0
      isReviewCompleted = reviewItems.isEmpty
      showingAnswer = false
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
      reviewItems = []
      isReviewCompleted = false
    }
  }

  private func answer(_ grade: AnkiModels.ReviewGrade) {
    let item = reviewItems[currentIndex]
    item.updateReview(grade: grade)
    try? modelContext.save()
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

#Preview {
  AnkiView()
    .modelContainer(for: [AnkiModels.Tag.self, AnkiModels.ExpressionItem.self])
}
