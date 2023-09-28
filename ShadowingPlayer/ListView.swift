import SwiftUI

struct ListView: View {

  let items: [Item] = Item.globInBundle()

  @State private var currentItem: Item_Hashable?
  @State private var isImporting: Bool = false

  var body: some View {
    NavigationStack {

      List(items) { item in

        NavigationLink(value: Item_Hashable(body: item)) {
          Text(item.audioFileURL.lastPathComponent)
        }

      }
      .navigationDestination(for: Item_Hashable.self, destination: { item in
        PlayerView(playerController: try! .init(item: item.body))
      })
      .toolbar(content: {
        Button("Import") {
          isImporting = true
        }
      })
      .navigationTitle("Shadowing Player")
      .sheet(isPresented: $isImporting, content: {
        ImportView()
      })

    }
  }

}

#Preview {

  ListView()

}
