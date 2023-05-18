import SwiftUI

struct ListView: View {

  let items: [Item] = Item.globInBundle()

  var body: some View {
    NavigationStack {

      List(items) { item in

        NavigationLink(destination: PlayerView(item: item)) {
          Text(item.audioFileURL.lastPathComponent)
        }

      }
      .navigationTitle("Shadowing Player")
    }
  }

}
