import AppService
import SwiftData
import SwiftUI

struct AllItemsView: View {

  @Query(sort: \AnkiModels.ExpressionItem.front) private var allItems: [AnkiModels.ExpressionItem]

  let ankiService: AnkiService

  @State private var isPlaying = false
  let navigationNamespace: Namespace.ID
  @Namespace private var namespace

  init(
    ankiService: AnkiService,
    namespace: Namespace.ID
  ) {
    self.ankiService = ankiService
    self.navigationNamespace = namespace
  }

  var body: some View {
    List {
      Section(
        header: ItemsHeaderView(
          isPlaying: $isPlaying,
          namespace: namespace
        )         
      ) {
        ForEach(allItems) { item in
          NavigationLink(value: item) {
            AnkiItemCell(
              item: item
            )
            .matchedTransitionSource(id: item, in: navigationNamespace) { co in
              co
            }
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
      .navigationTransition(.zoom(sourceID: "A", in: namespace))
    }
  }

}
