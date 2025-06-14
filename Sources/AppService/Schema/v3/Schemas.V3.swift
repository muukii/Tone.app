import SwiftData

extension Schemas {
  public enum V3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(3, 0, 0) }
    public static var models: [any PersistentModel.Type] {      
      [
        Self.Pin.self,
        Self.Item.self,
        Self.Tag.self,
        Self.Segment.self,
      ]
    }
  }
}