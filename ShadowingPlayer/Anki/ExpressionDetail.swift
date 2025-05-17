import SwiftUI

struct ExpressionDetail: View {
  var item: AnkiModels.ExpressionItem
  let speechClient: SpeechClient

  var body: some View {    
    AnkiCardView(
      item: item,
      speechClient: speechClient,
      showingAnswer: true,
      onTap: {}
    )     
    .padding(.horizontal)
  }
} 
