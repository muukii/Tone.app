import SwiftUI

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