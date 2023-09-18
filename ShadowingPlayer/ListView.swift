import SwiftUI

struct ListView: View {

  let items: [Item] = Item.globInBundle()

  @State private var currentItem: Item_Hashable?

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
      .navigationTitle("Shadowing Player")
    }
  }

}
