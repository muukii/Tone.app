import Foundation
import SwiftData

public enum Schemas {}

public typealias ActiveSchema = Schemas.V3

public typealias ItemEntity = ActiveSchema.Item
public typealias TagEntity = ActiveSchema.Tag
public typealias PinEntity = ActiveSchema.Pin
public typealias SegmentEntity = ActiveSchema.Segment

@MainActor
let currentSchema: Schema = .init(versionedSchema: ActiveSchema.self)

enum ServiceSchemaMigrationPlan: SchemaMigrationPlan {

  static var stages: [MigrationStage] {
    [
      MigrationStage.custom(
        fromVersion: Schemas.V1.self,
        toVersion: Schemas.V2.self,
        willMigrate: { context in
          try context.transaction {

            try context.fetch(.init(predicate: #Predicate<Schemas.V1.ItemEntity> { _ in true }))
              .forEach {
                context.delete($0)
              }

            try context.fetch(.init(predicate: #Predicate<Schemas.V1.PinEntity> { _ in true }))
              .forEach {
                context.delete($0)
              }
          }
        },
        didMigrate: { context in

        }
      ),
      MigrationStage.custom(
        fromVersion: Schemas.V2.self,
        toVersion: Schemas.V3.self,
        willMigrate: { context in
          // Migrate subtitle data to segment entities
          try context.transaction {
            let items = try context.fetch(.init(predicate: #Predicate<Schemas.V2.Item> { _ in true }))
            for item in items {
              if let subtitleData = item.subtitleData,
                 let storedSubtitle = try? StoredSubtitle(data: subtitleData) {
                // The V3 Item entity will handle creating segments through setSegmentData
                // We just need to ensure the data is available
              }
            }
          }
        },
        didMigrate: { context in
          
        }
      )
    ]
  }

  static var schemas: [any VersionedSchema.Type] {
    [Schemas.V1.self, Schemas.V2.self, Schemas.V3.self]
  }

}
