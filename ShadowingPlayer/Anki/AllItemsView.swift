import AppService
import SwiftData
import SwiftUI

struct AllItemsView: View {

  @Query(sort: \AnkiModels.ExpressionItem.front) private var allItems: [AnkiModels.ExpressionItem]

  let ankiService: AnkiService

  @State private var isPlaying = false
  let navigationNamespace: Namespace.ID
  @Namespace private var namespace

  @State private var reviewItems: [AnkiModels.ExpressionItem] = []
  @State private var nonReviewItems: [AnkiModels.ExpressionItem] = []

  init(
    ankiService: AnkiService,
    namespace: Namespace.ID
  ) {
    self.ankiService = ankiService
    self.navigationNamespace = namespace
  }

  var body: some View {
    List {
      Section(header: Text("本日復習対象")) {
        ForEach(reviewItems) { item in
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
      Section(header: Text("その他")) {
        ForEach(nonReviewItems) { item in
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
    .onChange(of: allItems, initial: true) { _, newItems in
      let todayItems = Set(ankiService.itemsForReviewToday())
      reviewItems = newItems
        .filter { todayItems.contains($0) }
        .sorted { ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast) }
      nonReviewItems = newItems
        .filter { !todayItems.contains($0) }
        .sorted { ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast) }
    }
    .navigationTitle("All Items")
    .sheet(isPresented: $isPlaying) {
      AnkiCardStackView(
        items: { ankiService.itemsForReviewToday() },
        service: ankiService
      )
      .navigationTransition(.zoom(sourceID: "A", in: namespace))
    }
  }

}
