
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {

  @State private var isAudioSelectingFiles: Bool = false
  @State private var isSubtitleSelectingFiles: Bool = false

  @State private var audioFileURL: URL?
  @State private var subtitleFileURL: URL?
  @State private var title: String = ""

  var body: some View {

    let modifier = if isAudioSelectingFiles {
      ImporterModifier(
        isPresented: $isAudioSelectingFiles,
        allowedContentTypes: [.mp3, .aiff],
        onCompletion: { result in
          switch result {
          case .success(let success):
            guard let first = success.first else {
              return
            }

            audioFileURL = first

            // Set title from filename as default
            if title == "" {
              title = first.deletingPathExtension().lastPathComponent
            }

          case .failure(let failure):
            print(failure)
          }
        })
    } else if isSubtitleSelectingFiles {
      ImporterModifier(
        isPresented: $isSubtitleSelectingFiles,
        allowedContentTypes: [
          .init(filenameExtension: "srt")!,
        ],
        onCompletion: { result in
          switch result {
          case .success(let success):
            guard let first = success.first else {
              return
            }

            subtitleFileURL = first

          case .failure(let failure):
            print(failure)
          }
      })
    } else {
      ImporterModifier(
        isPresented: .constant(false),
        allowedContentTypes: [],
        onCompletion: { _ in
        })
    }

    VStack {

      Form {

        TextField("Title", text: $title)

        Button("Audio") {
          isAudioSelectingFiles = true
        }

        Text("\(audioFileURL?.lastPathComponent.description ?? "unselected")")

        Button("Subtitle") {
          isSubtitleSelectingFiles = true
        }

        Text("\(subtitleFileURL?.lastPathComponent.description ?? "unselected")")

        Button("Import") {
          importFiles()
        }
        .disabled(audioFileURL == nil || subtitleFileURL == nil)

      }

    }
    .modifier(modifier)
    .onAppear {
      Item.globInDocuments()
    }

  }

  private func importFiles() {

    guard title.isEmpty == false else {
      return
    }

    guard let audioFileURL = audioFileURL else {
      return
    }

    guard let subtitleFileURL = subtitleFileURL else {
      return
    }

    guard audioFileURL.startAccessingSecurityScopedResource() else {      
      Log.error("Failed to start accessing security scoped resource")
      return
    }

    guard subtitleFileURL.startAccessingSecurityScopedResource() else {
      Log.error("Failed to start accessing security scoped resource")
      return
    }

    defer {
      audioFileURL.stopAccessingSecurityScopedResource()
      subtitleFileURL.stopAccessingSecurityScopedResource()
    }

    let target = URL.documentsDirectory.appendingPathComponent("audio", isDirectory: true)

    do {

      if FileManager.default.fileExists(atPath: target.absoluteString) == false {

        try FileManager.default.createDirectory(
          at: target,
          withIntermediateDirectories: true,
          attributes: nil
        )
      }

      try FileManager.default.copyItem(
        at: audioFileURL,
        to: target.appendingPathComponent(title + "." + audioFileURL.pathExtension)
      )

      try FileManager.default.copyItem(
        at: subtitleFileURL,
        to: target.appendingPathComponent(title + ".srt")
      )

    } catch {
      print(error)
    }

  }

  private struct ImporterModifier: ViewModifier {

    @Binding var isPresented: Bool
    let allowedContentTypes: [UTType]
    let onCompletion: (Result<[URL], Error>) -> Void

    func body(content: Content) -> some View {
      content.fileImporter(
        isPresented: $isPresented,
        allowedContentTypes: allowedContentTypes,
        allowsMultipleSelection: false,
        onCompletion: { result in
          onCompletion(result)
        }
      )
    }

  }
}

#Preview {
  ImportView()
}
