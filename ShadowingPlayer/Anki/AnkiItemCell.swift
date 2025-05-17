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
        Text("次回レビュー: \(dateString(from: nextReviewAt))")
          .font(.caption)
          .foregroundColor(.blue)
      } else {
        Text("次回レビュー: 未定")
          .font(.caption)
          .foregroundColor(.gray)
      }

      // 覚えている度合い（repetition回数とeaseFactorで表示）
      HStack(spacing: 12) {
        Text("連続正解: \(item.repetition)回")
          .font(.caption2)
          .foregroundColor(.green)
        Text(String(format: "E-Factor: %.2f", item.easeFactor))
          .font(.caption2)
          .foregroundColor(.orange)
      }
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.gray, lineWidth: 1)
    )
    .padding(.horizontal)
  }

  private func dateString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}
