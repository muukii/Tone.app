import SwiftUI
import SwiftData

struct TagDetailView: View {
  let tag: AnkiModels.Tag

  @Query private var dueItems: [AnkiModels.ExpressionItem]
  @Query private var notDueItems: [AnkiModels.ExpressionItem]

  init(tag: AnkiModels.Tag) {
    let tagName = tag.name
    let today = Date()
    // 復習対象
    self._dueItems = Query(
      filter: #Predicate<AnkiModels.ExpressionItem> { item in
        item.tags!.contains(where: { $0.name == tagName }) == true &&
        (item.nextReviewAt == nil || item.nextReviewAt! <= today)
      },
      sort: [
        SortDescriptor(\.repetition, order: .forward)
      ]
    )
    // 復習不要
    self._notDueItems = Query(
      filter: #Predicate<AnkiModels.ExpressionItem> { item in
        item.tags!.contains(where: { $0.name == tagName }) == true &&
        (item.nextReviewAt != nil && item.nextReviewAt! > today)
      },
      sort: [
        SortDescriptor(\.nextReviewAt, order: .forward),
        SortDescriptor(\.repetition, order: .forward)
      ]
    )
    self.tag = tag
  }

  var body: some View {
    List {
      ForEach(dueItems + notDueItems) { item in
        NavigationLink(value: item) {
          Text(item.front!)
        }
      }
    }
    .navigationTitle(tag.name ?? "")
  }
} 