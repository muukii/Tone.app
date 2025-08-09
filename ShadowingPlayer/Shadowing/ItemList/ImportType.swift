import SwiftUI
import AppService

enum ImportType: Identifiable {
  case audioAndSRT
  case audioFromFiles
  case videoFromPhotos
  case youTube
  
  var id: Self { self }
}

// Wrapper views for modifiers that need to be presented as sheets
struct AudioImportViewWrapper: View {
  let service: Service
  let defaultTag: TagEntity?
  let onDismiss: () -> Void
  
  @State private var isPresented = true
  
  var body: some View {
    Color.clear
      .modifier(
        ImportModifier(
          isPresented: $isPresented,
          service: service,
          defaultTag: defaultTag
        )
      )
      .onChange(of: isPresented) { _, newValue in
        if !newValue {
          onDismiss()
        }
      }
      .onAppear {
        isPresented = true
      }
  }
}

struct PhotosVideoPickerViewWrapper: View {
  let service: Service
  let defaultTag: TagEntity?
  let onDismiss: () -> Void
  
  @State private var isPresented = true
  
  var body: some View {
    Color.clear
      .modifier(
        PhotosVideoPickerModifier(
          isPresented: $isPresented,
          service: service,
          defaultTag: defaultTag
        )
      )
      .onChange(of: isPresented) { _, newValue in
        if !newValue {
          onDismiss()
        }
      }
      .onAppear {
        isPresented = true
      }
  }
}