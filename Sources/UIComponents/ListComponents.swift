import SwiftUI

public enum ListComponents {
  
  public struct Cell<Content: View>: View {
    
    let content: Content
    
    public init(
      @ViewBuilder content: () -> Content
    ) {
      self.content = content()
    }
    
    public var body: some View {
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
  
  public struct Header: View {
    
    let title: String
    
    public init(title: String) {
      self.title = title
    }
    
    public var body: some View {
      Text(title)
        .font(.system(size: 20, weight: .bold, design: .default))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .foregroundStyle(.primary)
    }
  }
  
}