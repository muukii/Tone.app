import _Concurrency

/**
 Performs the given task in background
 */
public nonisolated func withBackground<Return: Sendable>(
  _ thunk: @escaping @isolated(any) @Sendable () async throws -> Return
) async rethrows -> Return {

  // here is the background as it's nonisolated
  // to inherit current actor context, use @_unsafeInheritExecutor

  // thunk closure runs on the background as it's sendable
  // if it's not sendable, inherit current actor context but it's already background.
  // @_inheritActorContext makes closure runs on current actor context even if it's sendable.
  return try await thunk()
}

extension Task {
  
  /**
   Performs the given task in background
   It inherits the current actor context compared to Task.detached.
   */
  @discardableResult
  public static func background(
    priority: TaskPriority? = nil,
    operation: @escaping @isolated(any) @Sendable () async throws -> Success
  ) -> Self where Failure == Error {
    return .init(priority: priority) {
      return try await withBackground(operation)
    }
  }
  
}
