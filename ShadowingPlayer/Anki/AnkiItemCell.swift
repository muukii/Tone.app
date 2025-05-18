import SwiftUI

struct AnkiItemCell: View {
  
  let front: String?
  let nextReviewAt: Date?
  let masteryLevel: AnkiModels.ExpressionItem.MasteryLevel

  init(item: AnkiModels.ExpressionItem) {
    self.front = item.front
    self.nextReviewAt = item.nextReviewAt
    self.masteryLevel = item.masteryLevel    
  }
  
  init(
    front: String?,
    nextReviewAt: Date?,
    masteryLevel: AnkiModels.V1.ExpressionItem.MasteryLevel
  ) {
    self.front = front
    self.nextReviewAt = nextReviewAt
    self.masteryLevel = masteryLevel
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Front
      Text(front ?? "")
        .font(.headline)

      // 次回レビュー日
      if let nextReviewAt = nextReviewAt {       
//        TagView(tag: "\(duration(for: nextReviewAt)) h")
        Text(
          timerInterval: Date.now...nextReviewAt,
          showsHours: true
        )
      }

      // 覚えている度合い（masteryLevelで表示）
      Text("習得度: \(masteryLevelLabel(for: masteryLevel))")
        .font(.caption2)
        .foregroundColor(.purple)
    }
  }

  private func masteryLevelLabel(for level: AnkiModels.V1.ExpressionItem.MasteryLevel) -> String {
    switch level {
    case .level1:
      return "覚えていない"
    case .level2:
      return "初級"
    case .level3:
      return "中級"
    case .level4:
      return "上級"
    case .level5:
      return "マスター"
    }
  }
  
  private func duration(for date: Date) -> Int {
    let now = Date()
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour], from: now, to: date)
    return components.hour ?? 0
  }
}

#Preview("Level3") {
  AnkiItemCell(
    front: "Hello",
    nextReviewAt: Date().addingTimeInterval(3600),
    masteryLevel: .level3
  )
}

#Preview("No Review Date") {
  AnkiItemCell(
    front: "World",
    nextReviewAt: nil,
    masteryLevel: .level1
  )
}
