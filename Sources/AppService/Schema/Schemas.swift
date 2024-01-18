import SwiftData

public enum Schemas {}

public typealias ItemEntity = Schemas.V1.ItemEntity
public typealias PinEntity = Schemas.V1.PinEntity

let currentSchema: Schema = .init(versionedSchema: Schemas.V1.self)

enum ServiceSchemaMigrationPlan: SchemaMigrationPlan {

  static var stages: [MigrationStage] {
    [
    ]
  }

  static var schemas: [any VersionedSchema.Type] {
    [Schemas.V1.self]
  }

//  private static let migrateV1toV2 = MigrationStage.lightweight(
//    fromVersion: Schemas.V1.self,
//    toVersion: UserSchemaV2.self
//  )
}
