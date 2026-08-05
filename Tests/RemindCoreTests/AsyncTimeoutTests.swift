import Foundation
import Testing

@testable import RemindCore

private final class TimeoutGate: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Void, Never>?
  private var isOpen = false

  var didOpen: Bool {
    lock.withLock { isOpen }
  }

  func wait() async {
    await withCheckedContinuation { continuation in
      let resumeImmediately = lock.withLock {
        if isOpen {
          return true
        }
        self.continuation = continuation
        return false
      }
      if resumeImmediately {
        continuation.resume()
      }
    }
  }

  func open() {
    let continuation = lock.withLock {
      isOpen = true
      let pending = self.continuation
      self.continuation = nil
      return pending
    }
    continuation?.resume()
  }
}

struct AsyncTimeoutTests {
  @Test("withTimeout returns when the operation finishes first")
  func succeedsWhenOperationFinishesFirst() async throws {
    let gate = TimeoutGate()
    let value = try await AsyncTimeout.withTimeout(
      nanoseconds: 1_000_000_000,
      timeoutMessage: "should not time out",
      onTimeout: { gate.open() },
      operation: {
        "ok"
      })
    #expect(value == "ok")
    #expect(!gate.didOpen)
  }

  @Test("withTimeout releases a non-cooperative operation before throwing")
  func releasesNonCooperativeOperationBeforeThrowing() async {
    let gate = TimeoutGate()
    await #expect(throws: RemindCoreError.operationFailed("timed out")) {
      try await AsyncTimeout.withTimeout(
        nanoseconds: 50_000_000,
        timeoutMessage: "timed out",
        onTimeout: { gate.open() },
        operation: {
          await gate.wait()
          return "released"
        })
    }
    #expect(gate.didOpen)
  }
}
