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

  var body: some View {
    NavigationStack {

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
          }
        }

      }
      .navigationDestination(for: PinEntity.self, destination: { pin in

      })
      .navigationDestination(for: ItemEntity.self, destination: { item in
        PlayerView(
          playerController: try! .init(item: item),
          focusingID: nil,
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

                  modelContext.insert(new)
                }
              } catch {
                Log.error("Failed to make a pin entity. \(error)")
              }

              break
            }
          })
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
