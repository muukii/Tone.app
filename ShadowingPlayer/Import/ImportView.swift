import AppService
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {

  private let audioUTTypes: Set<UTType> = [
    .mp3, .aiff, .wav, .mpeg4Audio,
  ]

  private let srtUTType = UTType(filenameExtension: "srt")!

  @State private var isSelectingFiles: Bool = false

  @State private var isEditingMultipleDrafts: Bool = false
  @State private var selectedMultipleDrafts: [Draft]? = nil
  @Environment(\.modelContext) var modelContext

  let service: Service

  var onCompleted: () -> Void
  var onCancel: () -> Void

  var body: some View {

    NavigationStack {

      ImportContentView(onImport: { draft in

        Task {
          try await service.importItem(title: draft.title, audioFileURL: draft.audioFileURL, subtitleFileURL: draft.subtitleFileURL)
          onCompleted()
        }

      })
      .navigationBarTitle("Import")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onCancel()
          }
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button("Batch") {
            isSelectingFiles = true
          }
        }
      }
      .navigationDestination(isPresented: $isEditingMultipleDrafts, destination: {
        if let drafts = selectedMultipleDrafts {
          MultipleImportEditView(
            drafts: drafts,
            onConfirm: {
              Task {
                for draft in drafts {
                  try await service.importItem(title: draft.title, audioFileURL: draft.audioFileURL, subtitleFileURL: draft.subtitleFileURL)
                }
                onCompleted()
              }
            }
          )
        }
      })

    }
    .fileImporter(
      isPresented: $isSelectingFiles,
      allowedContentTypes: Array(audioUTTypes) + CollectionOfOne(srtUTType),
      allowsMultipleSelection: true,
      onCompletion: { result in
        switch result {
        case .success(let success):

          // find matching audio files and srt files using same file name

          let audioFiles = Set(
            success.filter {
              for type in audioUTTypes {
                if UTType(filenameExtension: $0.pathExtension)?.conforms(to: type) == true {
                  return true
                }
              }
              return false
            }
          )

          let srtFiles = Set(
            success.filter {
              UTType(filenameExtension: $0.pathExtension)?.conforms(to: srtUTType) == true
            }
          )

          let drafts = audioFiles.compactMap { url -> Draft? in

            let name = url.deletingPathExtension().lastPathComponent

            guard
              let srtURL = srtFiles.first(where: {
                $0.deletingPathExtension().lastPathComponent == name
              })
            else {
              return nil
            }

            return Draft(title: name, audioFileURL: url, subtitleFileURL: srtURL)
          }

          selectedMultipleDrafts = drafts
          isEditingMultipleDrafts = true

        case .failure(let failure):
          print(failure)
        }
      }
    )

  }
}

private struct Draft: Identifiable {

  var id: String { title }

  let title: String
  let audioFileURL: URL
  let subtitleFileURL: URL

}

private struct MultipleImportEditView: View {

  let drafts: [Draft]

  var onConfirm: @MainActor () -> Void

  var body: some View {

    List.init(drafts) { draft in

      VStack(alignment: .leading) {

        Text(draft.title)
          .font(.headline)
          .padding(.bottom, 4)

        Text(draft.audioFileURL.path)
          .font(.caption)
          .foregroundColor(.secondary)

        Text(draft.subtitleFileURL.path)
          .font(.caption)
          .foregroundColor(.secondary)

      }
    }
    .toolbar(content: {
      ToolbarItem(placement: .confirmationAction) {
        Button("Import") {
          onConfirm()
        }
      }
    })

  }

}

private struct ImportContentView: View {

  @State private var isAudioSelectingFiles: Bool = false
  @State private var isSubtitleSelectingFiles: Bool = false

  @State private var audioFileURL: URL?
  @State private var subtitleFileURL: URL?
  @State private var title: String = ""

  var onImport: (Draft) -> Void

  var body: some View {

    let modifier =
      if isAudioSelectingFiles {
        ImporterModifier(
          isPresented: $isAudioSelectingFiles,
          allowedContentTypes: [.mp3, .aiff, .wav, .mpeg4Audio],
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
          }
        )
      } else if isSubtitleSelectingFiles {
        ImporterModifier(
          isPresented: $isSubtitleSelectingFiles,
          allowedContentTypes: [
            .init(filenameExtension: "srt")!
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
          }
        )
      } else {
        ImporterModifier(
          isPresented: .constant(false),
          allowedContentTypes: [],
          onCompletion: { _ in
          }
        )
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

#Preview {
  ImportView(
    service: .init(),
    onCompleted: {

    },
    onCancel: {

    }
  )
}
