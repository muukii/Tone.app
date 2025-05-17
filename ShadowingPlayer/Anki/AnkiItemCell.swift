import SwiftUI

struct AnkiItemCell: View {
  let item: AnkiModels.ExpressionItem

  init(item: AnkiModels.ExpressionItem) {
    self.item = item
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Front
      Text(item.front ?? "")
        .font(.headline)

      // 次回レビュー日
      if let nextReviewAt = item.nextReviewAt {
        Text("次回レビュー: \(nextReviewAt, format: .dateTime)")
          .font(.caption)
          .foregroundColor(.blue)
      } else {
        Text("次回レビュー: 未定")
          .font(.caption)
          .foregroundColor(.gray)
      }

      // 覚えている度合い（masteryLevelで表示）
      Text("習得度: \(masteryLevelLabel(for: item.masteryLevel))")
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
}
