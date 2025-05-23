import SwiftUI

struct ExpressionDetail: View {
  
  var item: AnkiModels.ExpressionItem
  let speechClient: SpeechClient
  let service: AnkiService
  
  @State private var isEditing: Bool = false
  
  init(
    service: AnkiService,
    item: AnkiModels.ExpressionItem,
    speechClient: SpeechClient
  ) {    
    self.service = service
    self.item = item
    self.speechClient = speechClient
  }

  var body: some View {    
    AnkiCardView(
      item: item,
      isEditing: $isEditing,
      speechClient: speechClient,
      showingAnswer: true,
      onTap: {}
    )     
    .padding(.horizontal)
    .sheet(isPresented: $isEditing) { 
      AnkiCardEditView(
        editing: item,
        service: service,
        onCancel: {
          isEditing = false        
      })
    }
  }
} 
