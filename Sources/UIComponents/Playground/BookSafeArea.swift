import SwiftUI

private struct _Book: View {

  var body: some View {

    NavigationStack {
      ScrollView {
        RoundedRectangle(cornerRadius: 20)
          .fill(Color.blue.opacity(0.2))
          .frame(height: 1000)
          .overlay { 
            NavigationLink { 
              
            } label: { 
              Text("Next")
            }
          }
      }      
    }
    .safeAreaInset(edge: .bottom) {
      RoundedRectangle(cornerRadius: 20)
        .fill(Color.red.opacity(0.2))
        .frame(height: 100)
        .background(Color.green.opacity(0.2))
    }
    

  }
}

#Preview("SafeArea") {
  _Book()
}
