import SwiftData

extension Schemas {
  public enum V1: VersionedSchema {
    public static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    public static var models: [any PersistentModel.Type] = [
      PinEntity.self,
      ItemEntity.self
    ]
  }
}
