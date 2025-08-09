import SwiftUI
import PhotosUI
import AppService

private struct PhotosVideoPickerModifier: ViewModifier {
  
  @Binding var isPresented: Bool
  @State var selectedItems: [PhotosPickerItem] = []
  let service: Service
  
  func body(content: Content) -> some View {
    content
      .photosPicker(
        isPresented: $isPresented,
        selection: $selectedItems,
        matching: .videos
      )
      .onChange(of: selectedItems) { _, newItems in
        print(newItems)
      }
  }
}

extension View {
  func photosVideoPicker(isPresented: Binding<Bool>, service: Service) -> some View {
    self.modifier(PhotosVideoPickerModifier(isPresented: isPresented, service: service))
  }
}
