import AppService
import SwiftUI

struct AudioItemCell: View {

  let title: String
  let tags: [String]

  init(item: ItemEntity) {

    self.init(
      title: item.title,
      tags: item.tags?.compactMap { $0.name } ?? []
    )
  }

  init(
    title: String,
    tags: [String]
  ) {
    self.title = title
    self.tags = tags
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("\(title)")
    }
  }
}

#Preview {
  Form {
    AudioItemCell(
      title: "Hello, Tone.",
      tags: ["English", "Japanese"]
    )
  }
}
