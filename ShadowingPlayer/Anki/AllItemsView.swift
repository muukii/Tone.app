import AppService
import SwiftData
import SwiftUI

struct AllItemsView: View {

  @Query(sort: \AnkiModels.ExpressionItem.front) private var allItems: [AnkiModels.ExpressionItem]

  let ankiService: AnkiService

  @State private var isPlaying = false

  init(ankiService: AnkiService) {
    self.ankiService = ankiService
  }

  var body: some View {
    List {
      Section(header: ItemsHeaderView(isPlaying: $isPlaying)) {
        ForEach(allItems) { item in
          NavigationLink(value: item) {
            AnkiItemCell(
              item: item
            )
          }
          .contextMenu {
            Button("Delete", role: .destructive) {
              ankiService.delete(item: item)
            }
          }
        }
      }
    }
    .navigationTitle("All Items")
    .sheet(isPresented: $isPlaying) {
      AnkiCardStackView(
        items: ankiService.itemsForReviewToday(),
        service: ankiService
      )
    }
  }

}
