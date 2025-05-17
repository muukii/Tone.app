import SwiftUI

struct ItemsHeaderView: View {
  
  @Binding private var isPlaying: Bool
  
  init(isPlaying: Binding<Bool>) {
    self._isPlaying = isPlaying
  }

  var body: some View {
    VStack {
      
      Button("Start") {
        isPlaying = true
      }
      .buttonStyle(.borderedProminent)
    }
  }
} 