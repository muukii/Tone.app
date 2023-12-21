import Foundation
import SwiftData

@MainActor
public final class Service {

  public let modelContainer: ModelContainer

  public nonisolated init() {

    let databasePath = URL.documentsDirectory.appending(path: "database")
    do {
      let container = try ModelContainer(
        for: ItemEntity.self,
        PinEntity.self,
        configurations: .init(url: databasePath)
      )
      self.modelContainer = container
    } catch {
      // TODO: delete database if schema mismatches or consider migration
      Log.error("\(error)")
      fatalError()
    }

  }

  public func makePinned() async throws {

    

  }

  public func importItem(title: String, audioFileURL: URL, subtitleFileURL: URL) async throws {

    let modelContext = ModelContext(modelContainer)

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

      let audioFileDestinationPath = AbsolutePath(
        url: target.appendingPathComponent(title + "." + audioFileURL.pathExtension)
      )
      let subtitleFileDestinationPath = AbsolutePath(
        url: target.appendingPathComponent(title + ".srt")
      )
      do {
        try overwrite(file: audioFileURL, to: audioFileDestinationPath.url)
      }

      do {
        try overwrite(file: subtitleFileURL, to: subtitleFileDestinationPath.url)
      }

      try modelContext.transaction {

        let new = ItemEntity()

        new.createdAt = .init()
        new.title = title
        new.subtitleFilePath =
          subtitleFileDestinationPath.relative(basedOn: .init(url: URL.documentsDirectory)).rawValue
        new.audioFilePath =
          audioFileDestinationPath.relative(basedOn: .init(url: URL.documentsDirectory)).rawValue

        modelContext.insert(new)

      }

    }
  }
}
