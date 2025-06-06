import SwiftUI

private struct _Book<MainContent: View, ControlContent: View>: View {
  
  let mainContent: MainContent
  let controlContent: ControlContent
  
  init(
    @ViewBuilder mainContent: () -> MainContent,
    @ViewBuilder controlContent: () -> ControlContent
  ) {
    self.mainContent = mainContent()
    self.controlContent = controlContent()
  }
  
  var body: some View {
    ZStack {      
      Rectangle()
        .fill(.background)
        .environment(\.colorScheme, .dark)
        
      ZStack {
        
        Color.red
          .ignoresSafeArea()
        
        mainContent
        
      }
      .frame(maxHeight: .infinity)
      .mask(        
        RoundedRectangle(
          cornerRadius: 30
        )   
        .ignoresSafeArea(edges: .top)
      )
    }    
    .safeAreaInset(
      edge: .bottom,
      spacing: 0
    ) { 
      controlContent
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.background)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.colorScheme, .dark)
    }
  }
}

#Preview("Platter") {
  _Book(
    mainContent: {
      VStack {
        Text("コンテンツ")
      }
    },
    controlContent: {
      Text("Hello")
    }
  )
}
