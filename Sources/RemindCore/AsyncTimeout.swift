import Foundation

enum AsyncTimeout {
  /// Race `operation` against a deadline. Cancels remaining tasks when the first completes.
  static func withTimeout<T: Sendable>(
    nanoseconds: UInt64,
    timeoutMessage: String,
    operation: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        try await operation()
      }
      group.addTask {
        try await Task.sleep(nanoseconds: nanoseconds)
        throw RemindCoreError.operationFailed(timeoutMessage)
      }
      defer { group.cancelAll() }
      guard let value = try await group.next() else {
        throw RemindCoreError.operationFailed(timeoutMessage)
      }
      return value
    }
  }
}
