import SwiftUI
import SwiftData

struct ListView: View {

  let items: [Item] = Item.globInBundle()

  @Query(sort: \ItemEntity.createdAt, order: .reverse)
  var itemEntities: [ItemEntity]

  @Query(sort: \PinEntity.createdAt, order: .reverse)
  var pinEntities: [PinEntity]

  @Environment(\.modelContext) var modelContext

  @State private var isImporting: Bool = false

  @State var path: NavigationPath = .init()

  var body: some View {
    NavigationStack(path: $path) {

      List {

        Section {
          ForEach(itemEntities) { item in
            NavigationLink(value: item) {
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
        }

        Section {
          ForEach(pinEntities) { pin in
            NavigationLink(value: pin) {
              VStack {
                Text(pin.subtitle)
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
      .navigationDestination(for: PinEntity.self, destination: { pin in

        if let item = pin.item {
          ObjectProvider(object: {
            let controller = try! PlayerController(item: item)
            let _ = controller.setRepeating(identifier: pin.identifier)
            return controller
          }()) { controller in
            PlayerView(
              playerController: controller,
              actionHandler: { action in
                switch action {
                case .onPin(let cue):

                  do {
                    try modelContext.transaction {

                      let new = PinEntity()
                      new.createdAt = .init()
                      new.subtitle = cue.backed.text
                      new.startTime = cue.backed.startTime.timeInSeconds
                      new.endTime = cue.backed.endTime.timeInSeconds
                      new.identifier = cue.id

                      let targetItem = try modelContext.fetch(.init(predicate: #Predicate<ItemEntity> { [id = item.persistentModelID] in
                        $0.persistentModelID == id
                      })).first

                      guard let targetItem else {
                        assertionFailure("not found item")
                        return
                      }

                      new.item = targetItem

                      modelContext.insert(new)
                    }
                  } catch {
                    Log.error("Failed to make a pin entity. \(error)")
                  }

                  break
                }
              })
          }
        } else {
          EmptyView()
        }
      })
      .navigationDestination(for: ItemEntity.self, destination: { item in
        ObjectProvider(object: {
          let controller = try! PlayerController(item: item)
          return controller
        }()) { controller in
          PlayerView(
            playerController: controller,
            actionHandler: { action in
              switch action {
              case .onPin(let cue):

                do {
                  try modelContext.transaction {

                    let new = PinEntity()
                    new.createdAt = .init()
                    new.subtitle = cue.backed.text
                    new.startTime = cue.backed.startTime.timeInSeconds
                    new.endTime = cue.backed.endTime.timeInSeconds
                    new.identifier = cue.id

                    let targetItem = try modelContext.fetch(.init(predicate: #Predicate<ItemEntity> { [id = item.persistentModelID] in
                      $0.persistentModelID == id
                    })).first

                    guard let targetItem else {
                      assertionFailure("not found item")
                      return
                    }

                    new.item = targetItem

                    modelContext.insert(new)
                  }
                } catch {
                  Log.error("Failed to make a pin entity. \(error)")
                }

                break
              }
            })
        }
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
