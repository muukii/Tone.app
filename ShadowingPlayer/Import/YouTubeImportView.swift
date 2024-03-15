import AppService
import SwiftUI
import YouTubeKit

struct YouTubeImportView: View {

  let service: Service
  let onComplete: @MainActor () -> Void

  @State private var statusText: String = ""

  init(service: Service, onComplete: @escaping @MainActor () -> Void) {
    self.service = service
    self.onComplete = onComplete
  }

  var body: some View {
    YouTubeImportContentView(
      statusText: statusText,
      onTranscribe: { @MainActor url in
        do {
          
          statusText = "Fetching metadata..."

          let title = try await YouTube(url: url).metadata?.title

          statusText = "Downloading audio..."

          let audio = try await YouTubeDownloader.run(url: url)

          statusText = "Transcribing..."

          try await service.transcribe(
            title: title ?? "(Not fetched)",
            audioFileURL: audio
          )

          onComplete()

        } catch {

          statusText = "Error: \(error.localizedDescription)"
          Log.error("\(error.localizedDescription)")
        }
      }
    )
  }
}

private struct YouTubeImportContentView: View {

  @State private var urlString: String = ""
  @State private var url: URL? = nil

  @State private var isProcessing: Bool = false
  var statusText: String = ""

  var onTranscribe: @MainActor (URL) async -> Void

  var body: some View {

    VStack {
      TextField("URL to YouTube", text: $urlString)
        .textContentType(.URL)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .disabled(isProcessing)

      Button("Transcribe") {

        guard let url else { return }

        Task { @MainActor in
          isProcessing = true
          defer {
            isProcessing = false
          }

          await onTranscribe(url)

        }

      }
      .buttonStyle(.borderedProminent)
      .disabled(isProcessing || url == nil)

      ProgressView()
        .opacity(isProcessing ? 1 : 0)
      Text(statusText)
    }
    .padding()
    .onChange(of: urlString) { oldValue, newValue in
      let url = URL(string: newValue)
      self.url = url
    }

  }
}

#Preview {
  YouTubeImportContentView(onTranscribe: { _ in })
}

#if DEBUG
import SwiftUI

#Preview {
  _DebugView()
}

private struct _DebugView: View {

  var body: some View {
    VStack {
      Button("Run") {
        Task { @MainActor in
          let url = URL(string: "https://www.youtube.com/watch?v=8UwrcVIyvWA")!

          let video = YouTube(url: url)

          let streams = try await video.streams

          let stream = try await video.streams.filter {
            [FileExtension.aac, .m4a, .mp4, .mp3].contains($0.fileExtension)
          }
            .filterAudioOnly()
            .highestAudioBitrateStream()

          print(stream!.url)
          let v = try await URLSession.shared.download(from: stream!.url)

          print(v)

        }
      }

      Button("Download") {

        Task { @MainActor in
          let url = URL(string: "https://rr2---sn-oguelnzr.googlevideo.com/videoplayback/id/f14c2b715232bd60/itag/96/source/youtube/expire/1710084259/ei/Q3ztZZK8J-CdvcAP38-QqAw/ip/153.231.79.50/requiressl/yes/ratebypass/yes/pfa/1/sgoap/clen%3D9828695%3Bdur%3D607.271%3Bgir%3Dyes%3Bitag%3D140%3Blmt%3D1709554541390305/sgovp/clen%3D74574241%3Bdur%3D607.189%3Bgir%3Dyes%3Bitag%3D137%3Blmt%3D1709569299611441/rqh/1/hls_chunk_host/rr2---sn-oguelnzr.googlevideo.com/xpc/EgVo2aDSNQ%3D%3D/mh/TV/mm/31,29/mn/sn-oguelnzr,sn-oguesn6y/ms/au,rdu/mv/m/mvi/2/pl/20/initcwndbps/1096250/spc/UWF9fwqj9eXCFOoIYiv8zlms8OTVYvti0NzPg_l8hAe6pgI/vprv/1/playlist_type/CLEAN/txp/5532434/mt/1710062256/fvip/3/keepalive/yes/fexp/24007246/sparams/expire,ei,ip,id,itag,source,requiressl,ratebypass,pfa,sgoap,sgovp,rqh,xpc,spc,vprv,playlist_type/sig/AJfQdSswRQIhAJScOp4IgzBbPyvQe2XRrOR8riLv04wjt_QHOJQkxAgCAiAvwg1F7kWI2M4aEzDgfDXmlu3dHmMHhT1lXHsOZuirjQ%3D%3D/lsparams/hls_chunk_host,mh,mm,mn,ms,mv,mvi,pl,initcwndbps/lsig/APTiJQcwRAIgPfmgUGnINiaL95i9No-Fm7AVimCpBImIA4ndMbea5SECIHcgVIsrAMEgxCVH7_H9DE2VBHilgfh5xfMo_w940C9i/playlist/index.m3u8/govp/slices%3D0-738,74052558-74574240/goap/slices%3D0-631,9696094-9828694/begin/601684/len/5506/gosq/115/file/seg.ts")!

          let v = try await URLSession.shared.download(from: url)

          print(v)
        }
      }

      Button("Download") {

        Task { @MainActor in
          let url = URL(string: "https://images.unsplash.com/photo-1709596046137-8f2d90fc973d?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")!

          let v = try await URLSession.shared.download(from: url)

          print(v)
        }
      }
    }
  }
}

#endif
