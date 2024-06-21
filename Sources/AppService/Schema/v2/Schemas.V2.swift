import SwiftData

extension Schemas {
  public enum V2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {      
      [
        Self.Pin.self,
        Self.Item.self,
      ]
    }
  }
}
