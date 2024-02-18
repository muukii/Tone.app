import AppService
import SwiftUI
import UniformTypeIdentifiers

struct AudioImportView: View {

  let service: Service

  let onComplete: @MainActor () -> Void

  var body: some View {
    AudioImportContentView(onCompleteTranscribing: { name, result in
      do {
        try await service.importItem(
          title: name,
          audioFileURL: result.audioFileURL,
          segments: result.segments.map { .init(segment: $0) }
        )
      } catch {
        print(error)
      }

      onComplete()
    })
  }
}

private struct AudioImportContentView: View {

  private let audioUTTypes: Set<UTType> = [
    .mp3, .aiff, .wav, .mpeg4Audio,
  ]

  @State private var isSelectingFiles: Bool = false

  @State private var processing: Bool = false

  let onCompleteTranscribing: @MainActor (String, WhisperTranscriber.Result) async -> Void

  var body: some View {

    ZStack(alignment: .init(horizontal: .center, vertical: .anchor)) {
      Color.clear
      VStack {
        Button("Import audio file") {
          isSelectingFiles = true
        }
        .alignmentGuide(.anchor, computeValue: { dimension in
          dimension[VerticalAlignment.center]
        })
        if processing {
          ProgressView()
        }
      }
    }
    .fileImporter(
      isPresented: $isSelectingFiles,
      allowedContentTypes: Array(audioUTTypes),
      allowsMultipleSelection: false,
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

          guard let targetFile = audioFiles.first else {
            return
          }

          let filename = targetFile.deletingPathExtension().lastPathComponent

          Task { @MainActor in

            processing = true
            defer {
              processing = false
            }

            do {

              let modelRef = WhisperModelRef.enSmall

              if await modelRef.isDownloaded() == false {
                try await WhisperModelDownloader.run(modelRef: modelRef)
              }

              try Task.checkCancellation()

              let result = try await WhisperTranscriber.run(url: targetFile, using: modelRef)

              try Task.checkCancellation()

              await onCompleteTranscribing(filename, result)
            } catch {
              print(error)
            }

          }

        case .failure(let failure):
          print(failure)
        }
      }
    )
    .interactiveDismissDisabled(processing)

  }

}

private extension VerticalAlignment {
  private enum Anchor : AlignmentID {
    static func defaultValue(in d: ViewDimensions) -> CGFloat {
      return d[VerticalAlignment.center]
    }
  }
  static let anchor = VerticalAlignment(Anchor.self)
}


#Preview {
  AudioImportContentView(onCompleteTranscribing: { name, result in })
}
