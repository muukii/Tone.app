import AppService
import SwiftData
import SwiftUI

struct ListView: View {

  //  typealias UsingDisplay = PlayerListDisplayView
  typealias UsingDisplay = PlayerListFlowLayoutView
  //  typealias UsingDisplay = PlayerListHorizontalView

  let service: Service

  @Query(sort: \ItemEntity.createdAt, order: .reverse)
  var itemEntities: [ItemEntity]

  @Query(sort: \PinEntity.createdAt, order: .reverse)
  var pinEntities: [PinEntity]

  let isSettinsEnabled = false

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
                // TODO: too direct
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
                // TODO: too direct
                modelContext.delete(pin)
              }
            })
          }
        }

      }
      .overlay {
        if itemEntities.isEmpty {
          emptyView(onImport: {
            isInImporting = true
          })
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
        if isSettinsEnabled {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              isInSettings = true
            } label: {
              Image(systemName: "gearshape")
            }
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
          ImportMenuView(
            audioAndSubtitleImportView: {
              AudioAndSubtitleImportView(
                service: service,
                onComplete: {
                  isInImporting = false
                },
                onCancel: {
                  isInImporting = false
                }
              )
            },
            youTubeImportView: {
              YouTubeImportView(
                service: service,
                onComplete: {
                  isInImporting = false
                }
              )
            }
          )
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

private func emptyView(onImport: @escaping @MainActor () -> Void) -> some View {
  ContentUnavailableView {
    Text("Let's add your own contents")
  } description: {
    Text("You can add your own contents from the import button on the top right corner.")
  } actions: {
    Button("Import") {
      MainActor.assumeIsolated {
        onImport()
      }
    }
  }
}

private struct ItemCell: View {

  let title: String

  init(item: ItemEntity) {
    self.title = item.title
  }

  init(title: String) {
    self.title = title
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("\(title)")
    }
  }
}

#Preview("Empty", body: {
  emptyView(onImport: {})
})

#Preview {
  Form {
    ItemCell(title: "Hello, Tone.")
  }
}

#Preview {

  ListView(service: .init())

}
