import SwiftData

@ModelActor
actor BackgroundModelActor {

  func perform<T>(_ operation: sending (ModelContext) throws -> T) async throws -> T {
    try operation(ModelContext(modelContainer))
  }
}
