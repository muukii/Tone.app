import _Concurrency

/**
 Performs the given task in background
 */
public nonisolated func withBackground<Return: Sendable>(
  _ thunk: @escaping @Sendable () async throws -> Return
) async rethrows -> Return {

  // here is the background as it's nonisolated
  // to inherit current actor context, use @_unsafeInheritExecutor

  // thunk closure runs on the background as it's sendable
  // if it's not sendable, inherit current actor context but it's already background.
  // @_inheritActorContext makes closure runs on current actor context even if it's sendable.
  return try await thunk()
}
