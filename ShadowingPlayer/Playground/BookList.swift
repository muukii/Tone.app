import SwiftUI

private struct _Book: View {
  
  var body: some View {
    ScrollView {
      LazyVStack {
        Section {
          VStack(alignment: .leading) {
            Text("Title")
              .font(.headline)
            Text("Title")
              .font(.subheadline)
            
            RoundedRectangle(cornerRadius: 1)
              .frame(height: 1)
              .foregroundStyle(.quinary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24)
        } header: {
          
          Text("Header")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
      }
    }
  }
}

#Preview("List") {
  _Book()
}
