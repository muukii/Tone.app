import Foundation
import SwiftData

public enum Schemas {}

public typealias ActiveSchema = Schemas.V2

public typealias ItemEntity = ActiveSchema.ItemEntity
public typealias PinEntity = ActiveSchema.PinEntity

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
      )
    ]
  }

  static var schemas: [any VersionedSchema.Type] {
    [Schemas.V1.self, Schemas.V2.self]
  }

}
