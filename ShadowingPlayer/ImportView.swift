
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {

  @Environment(\.modelContext) var modelContext

  var onCompleted: () -> Void

  var body: some View {
    ImportContentView(onImport: { draft in

      guard draft.audioFileURL.startAccessingSecurityScopedResource() else {
        Log.error("Failed to start accessing security scoped resource")
        return
      }

      guard draft.subtitleFileURL.startAccessingSecurityScopedResource() else {
        Log.error("Failed to start accessing security scoped resource")
        return
      }

      defer {
        draft.audioFileURL.stopAccessingSecurityScopedResource()
        draft.subtitleFileURL.stopAccessingSecurityScopedResource()
      }

      let target = URL.documentsDirectory.appendingPathComponent("audio", isDirectory: true)

      let fileManager = FileManager.default

      do {

        if fileManager.fileExists(atPath: target.absoluteString) == false {

          try fileManager.createDirectory(
            at: target,
            withIntermediateDirectories: true,
            attributes: nil
          )
        }

        func overwrite(file: URL, to url: URL) throws {

          if fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
            try fileManager.removeItem(at: url)
          }

          try fileManager.copyItem(
            at: file,
            to: url
          )

        }

        let audioFileDestinationpath = target.appendingPathComponent(draft.title + "." + draft.audioFileURL.pathExtension)
        let subtitleFileDestinationPath = target.appendingPathComponent(draft.title + ".srt")
        do {
          try overwrite(file: draft.audioFileURL, to: audioFileDestinationpath)
        }

        do {
          try overwrite(file: draft.subtitleFileURL, to: subtitleFileDestinationPath)
        }

        try modelContext.transaction {

          let new = ItemEntity()

          new.createdAt = .init()
          new.title = draft.title
          new.subtitleFileURL = subtitleFileDestinationPath
          new.audioFileURL = audioFileDestinationpath

          modelContext.insert(new)

        }

        onCompleted()

      } catch {
        Log.error("\(error)")
      }

    })    
  }
}

fileprivate struct Draft {

  let title: String
  let audioFileURL: URL
  let subtitleFileURL: URL

}

fileprivate struct ImportContentView: View {

  @State private var isAudioSelectingFiles: Bool = false
  @State private var isSubtitleSelectingFiles: Bool = false

  @State private var audioFileURL: URL?
  @State private var subtitleFileURL: URL?
  @State private var title: String = ""

  var onImport: (Draft) -> Void

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

    let draft = Draft(
      title: title,
      audioFileURL: audioFileURL,
      subtitleFileURL: subtitleFileURL
    )

    onImport(draft)

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
  ImportView(onCompleted: {
    
  })
}
