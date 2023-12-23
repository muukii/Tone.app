import AppService
import SwiftData
import SwiftUI

struct ListView: View {

  //  typealias UsingDisplay = PlayerListDisplayView
  typealias UsingDisplay = PlayerListFlowLayoutView
  //  typealias UsingDisplay = PlayerListHorizontalView

  let service: Service

  let items: [Item] = Item.globInBundle()

  @Query(sort: \ItemEntity.createdAt, order: .reverse)
  var itemEntities: [ItemEntity]

  @Query(sort: \PinEntity.createdAt, order: .reverse)
  var pinEntities: [PinEntity]

  @Environment(\.modelContext) var modelContext

  @State private var isInImporting: Bool = false
  @State private var isInSettings: Bool = false

  @State var path: NavigationPath = .init()

  var body: some View {
    NavigationStack(path: $path) {

      List {
        Section {
          ForEach(itemEntities) { item in
            NavigationLink(value: item) {
              ItemCell(item: item)
            }
            .contextMenu(menuItems: {
              Button("Delete", role: .destructive) {
                modelContext.delete(item)
              }
            })
          }
        }

        Section {
          ForEach(pinEntities) { pin in
            NavigationLink(value: pin) {
              VStack {
                Text(pin.item?.title ?? "null")
              }
            }
            .contextMenu(menuItems: {
              Button("Delete", role: .destructive) {
                modelContext.delete(pin)
              }
            })
          }
        }

      }
      .navigationDestination(
        for: PinEntity.self,
        destination: { pin in

          if let item = pin.item {
            PlayerView<UsingDisplay>(
              playerController: {
                let controller = try! PlayerController(item: item)
                controller.setRepeating(from: pin)
                return controller
              },
              actionHandler: { action in
                switch action {
                case .onPin(let range):

                  Task {
                    try await service.makePinned(range: range, for: item)
                  }

                }
              }
            )
          } else {
            EmptyView()
          }
        }
      )
      .navigationDestination(
        for: ItemEntity.self,
        destination: { item in

          PlayerView<UsingDisplay>(
            playerController: {
              let controller = try! PlayerController(item: item)
              return controller
            },
            actionHandler: { action in
              switch action {
              case .onPin(let range):

                Task {
                  try await service.makePinned(range: range, for: item)
                }
              }
            }
          )
        }
      )
      .toolbar(content: {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            isInSettings = true
          } label: {
            Image(systemName: "gearshape")
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Import") {
            isInImporting = true
          }
        }
      })
      .navigationTitle("Tone")
      .sheet(
        isPresented: $isInImporting,
        content: {
          ImportView(onCompleted: {
            isInImporting = false
          })
        }
      )
      .sheet(
        isPresented: $isInSettings,
        content: {
          SettingsView()
        }
      )

    }
  }

}

struct ItemCell: View {

  let title: String
  let createdAt: Date

  init(item: ItemEntity) {
    self.title = item.title
    self.createdAt = item.createdAt
  }

  var body: some View {
    VStack {
      Text("\(title)")
      Text("\(createdAt)")
    }
  }
}

#Preview {

  ListView(service: .init())

}
