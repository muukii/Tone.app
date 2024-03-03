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

  @State private var isInSettings: Bool = false

  @State var path: NavigationPath = .init()

  @State private var isImportingAudioAndSRT: Bool = false
  @State private var isImportingAudio: Bool = false
  @State private var isImportingYouTube: Bool = false

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
          emptyView()
        }
      }
      .navigationDestination(
        for: PinEntity.self,
        destination: { pin in

          if let item = pin.item {

            PinEntitiesProvider(targetItem: item) { pins in
              PlayerView<UsingDisplay>(
                playerController: {
                  let controller = try! PlayerController(item: item)
                  controller.setRepeating(from: pin)
                  return controller
                },
                pins: pins,
                actionHandler: { action in
                  do {
                    switch action {
                    case .onPin(let range):
                      try await service.makePinned(range: range, for: item)
                    case .onTranscribeAgain:
                      try await service.updateTranscribe(for: item)
                      path = .init()
                    }
                  } catch {
                    Log.error("\(error.localizedDescription)")
                  }
                }
              )
            }
          } else {
            EmptyView()
          }
        }
      )
      .navigationDestination(
        for: ItemEntity.self,
        destination: { item in

          PinEntitiesProvider(targetItem: item) { pins in
            PlayerView<UsingDisplay>(
              playerController: {
                let controller = try! PlayerController(item: item)
                return controller
              },
              pins: pins,
              actionHandler: { action in
                do {
                  switch action {
                  case .onPin(let range):
                    try await service.makePinned(range: range, for: item)
                  case .onTranscribeAgain:
                    try await service.updateTranscribe(for: item)
                    path = .init()
                  }
                } catch {
                  Log.error("\(error.localizedDescription)")
                }
              }
            )
          }

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

          Menu {
            Button("File and SRT") {
              isImportingAudioAndSRT = true
            }
            Button("File (on-device transcribing)") {
              isImportingAudio = true
            }
            Button("YouTube (on-device transcribing)") {
              isImportingYouTube = true
            }
          } label: {
            Text("Import")
          }

        }
      })
      .navigationTitle("Tone")
      .sheet(
        isPresented: $isImportingAudioAndSRT,
        content: {
          AudioAndSubtitleImportView(
            service: service,
            onComplete: {
              isImportingAudioAndSRT = false
            },
            onCancel: {
              isImportingAudioAndSRT = false
            }
          )
        }
      )
      .sheet(isPresented: $isImportingAudio, content: {
        AudioImportView(service: service) {
          isImportingAudio = false
        }
      })
      .sheet(
        isPresented: $isImportingYouTube,
        content: {
          YouTubeImportView(
            service: service,
            onComplete: {
              isImportingYouTube = false
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

private func emptyView() -> some View {
  ContentUnavailableView {
    Text("Let's add your own contents")
  } description: {
    Text("You can add your own contents from the import button on the top right corner.")
  } actions: {
    // No Actions for now
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

struct PinEntitiesProvider<Content: View>: View {

  @Query var pinEntities: [PinEntity]

  private let content: ([PinEntity]) -> Content

  init(targetItem: ItemEntity, @ViewBuilder content: @escaping ([PinEntity]) -> Content) {

    self.content = content

    let predicate = #Predicate<PinEntity> { [identifier = targetItem.persistentModelID] in
      $0.item?.persistentModelID == identifier
    }

    self._pinEntities = Query.init(filter: predicate, sort: \.createdAt)
  }

  var body: some View {
    content(pinEntities)
  }

}

#Preview("Empty", body: {
  emptyView()
})

#Preview {
  Form {
    ItemCell(title: "Hello, Tone.")
  }
}

#Preview {

  ListView(service: .init())

}
