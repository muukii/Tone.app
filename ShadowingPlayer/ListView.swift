import SwiftUI
import SwiftData

struct ListView: View {

  let items: [Item] = Item.globInBundle()

  @Query(sort: \ItemEntity.createdAt, order: .reverse)
  var itemEntities: [ItemEntity]

  @Environment(\.modelContext) var modelContext

  @State private var currentItem: Item_Hashable?
  @State private var isImporting: Bool = false

  var body: some View {
    NavigationStack {

      List(itemEntities) { item in

        NavigationLink(value: Item_Hashable(body: item)) {
          VStack {
            Text("\(item.title ?? "")")
            Text("\(item.createdAt)")
          }
        }
        .contextMenu(menuItems: {
          Button("Delete", role: .destructive) {
            modelContext.delete(item)
          }
        })

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
        ImportView(onCompleted: {
          isImporting = false        
        })
      })

    }
  }

}

#Preview {

  ListView()

}
