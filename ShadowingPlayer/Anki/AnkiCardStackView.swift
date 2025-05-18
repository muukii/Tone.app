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
    NavigationStack {
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
