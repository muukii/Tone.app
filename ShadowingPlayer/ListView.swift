import SwiftUI

struct ListView: View {

  let items: [Item] = [.example, .overwhelmed, .make(name: "Why Aliens Might Already Be On Their Way To Us"), .make(name: "140_-_TO_POP_IN___OUT___OFF___ON___UP_A_Phrasal_Verb_a_Day_is_back")]

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
