import SwiftUI

struct ItemsHeaderView: View {
  
  @Binding private var isPlaying: Bool
  private let namespace: Namespace.ID
  
  init(
    isPlaying: Binding<Bool>,
    namespace: Namespace.ID
  ) {
    self._isPlaying = isPlaying
    self.namespace = namespace
  }

  var body: some View {
    VStack {
      
      Button("Start") {
        isPlaying = true
      }
      .buttonStyle(.borderedProminent)
      .matchedTransitionSource(id: "A", in: namespace)
    }
  }
} 
