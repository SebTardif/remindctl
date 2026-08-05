import Foundation

private final class TimeoutRace: @unchecked Sendable {
  private let lock = NSLock()
  private var isClaimed = false

  func claim() -> Bool {
    lock.withLock {
      guard !isClaimed else { return false }
      isClaimed = true
      return true
    }
  }
}

enum AsyncTimeout {
  /// Race `operation` against a deadline. Cancels remaining tasks when the first completes.
  static func withTimeout<T: Sendable>(
    nanoseconds: UInt64,
    timeoutMessage: String,
    onTimeout: @escaping @Sendable () -> Void = {},
    operation: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      let race = TimeoutRace()
      group.addTask {
        let outcome: Result<T, Error>
        do {
          outcome = .success(try await operation())
        } catch {
          outcome = .failure(error)
        }
        guard race.claim() else {
          return try await waitForCancellation()
        }
        return try outcome.get()
      }
      group.addTask {
        try await Task.sleep(nanoseconds: nanoseconds)
        guard race.claim() else {
          return try await waitForCancellation()
        }
        // Release non-cooperative operations before task-group teardown waits for them.
        onTimeout()
        throw RemindCoreError.operationFailed(timeoutMessage)
      }
      defer { group.cancelAll() }
      guard let value = try await group.next() else {
        throw RemindCoreError.operationFailed(timeoutMessage)
      }
      return value
    }
  }

  // Park the loser so it cannot beat the claimed winner into `group.next()`.
  private static func waitForCancellation<T: Sendable>() async throws -> T {
    try await Task.sleep(nanoseconds: .max)
    throw CancellationError()
  }
}
