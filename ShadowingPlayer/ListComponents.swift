import SwiftUI

enum ListComponents {
  
  struct Cell<Content: View>: View {
    
    let content: Content
    
    init(
      @ViewBuilder content: () -> Content
    ) {
      self.content = content()
    }
    
    var body: some View {
      VStack {
        content
        RoundedRectangle(cornerRadius: 1)
          .frame(height: 1)
          .foregroundStyle(.quinary)
      }
      .padding(.horizontal, 20)
      .contentShape(Rectangle())
    }    
  }
  
  struct Header: View {
    
    let title: String
    
    init(title: String) {
      self.title = title
    }
    
    var body: some View {
      Text(title)
        .font(.system(size: 20, weight: .bold, design: .default))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .foregroundStyle(.primary)
    }
  }
  
}
