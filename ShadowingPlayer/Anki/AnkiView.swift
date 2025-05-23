import SwiftUI
import SwiftData

struct AnkiView: View {
  
  struct ShowAllItems: Hashable {
    var id: UUID = .init()
  }
  
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \AnkiModels.Tag.name) private var tags: [AnkiModels.Tag]
  @Query(sort: \AnkiModels.ExpressionItem.front) private var allItems: [AnkiModels.ExpressionItem]
  
  @State private var showingAddView: Bool = false
  @State private var showingImportView: Bool = false
  @State private var editingItem: AnkiModels.ExpressionItem?
  @Namespace private var namespace
  
  let ankiService: AnkiService
  
  init(ankiService: AnkiService) {
    self.ankiService = ankiService
  }
  
  private var list: some View {
    List {
      
      if tags.isEmpty == false {
        
        // Tagごとのセクション
        Section(header: Text("Tags")) {
          ForEach(tags) { tag in
            if let name = tag.name {
              NavigationLink(value: tag) {
                Text(name)
              }
              .contextMenu {
                Button("Delete", role: .destructive) {
                  ankiService.delete(tag: tag)
                }
              }
            }
          }
        }
      } 
      // Allセクション
      Section(header: Text("All")) {
        NavigationLink(value: ShowAllItems()) { 
          Text("All Items")
        }
      }
      
    }
    
  }
  
  private var emptyView: some View {
    ContentUnavailableView {
      Text("No Items")
    } description: {
      Text("Add some expressions to start.")
    } actions: {
      Button(action: { showingAddView = true }) {
        Text("Add items")
      }
      .buttonStyle(.borderedProminent)
    }    
  }
  
  var body: some View {
    NavigationStack {
      
      Group {
        if allItems.isEmpty {
          emptyView
       } else {
          list
        }
      }
      .navigationTitle("Vocabulary")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Menu.init { 
            Button(action: { showingAddView = true }) {
              Label("Add", systemImage: "plus")
            }
            Button(action: { showingImportView = true }) {
              Label("Import", systemImage: "plus")
            }
          } label: { 
            Text("Add")
          }
        }
      }
      .sheet(isPresented: $showingAddView) {
        AnkiCardEditView(
          service: ankiService,
          onCancel: {
          showingAddView = false        
        })          
      }
      .sheet(item: $editingItem) { item in
        AnkiCardEditView(
          editing: item,
          service: ankiService,
          onCancel: {
            showingAddView = false        
          })  
      }
      .sheet(isPresented: $showingImportView) {
        AnkiImportView.init()
      }
      .navigationDestination(
        for: AnkiModels.ExpressionItem.self,
        destination: { item in
          ExpressionDetail(
            service: ankiService,
            item: item,            
            speechClient: SpeechClient()
          )
          .navigationTransition(.zoom(sourceID: item, in: namespace))
        }
      )
      .navigationDestination(
        for: ShowAllItems.self,
        destination: { _ in
          AllItemsView(ankiService: ankiService, namespace: namespace)
        }
      )
      .navigationDestination(
        for: AnkiModels.Tag.self,
        destination: { tag in
          TagDetailView(tag: tag)
        }
      )
    }
  }
}
