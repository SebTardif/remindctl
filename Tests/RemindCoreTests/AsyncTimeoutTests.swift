import Testing

@testable import RemindCore

struct AsyncTimeoutTests {
  @Test("withTimeout returns when the operation finishes first")
  func succeedsWhenOperationFinishesFirst() async throws {
    let value = try await AsyncTimeout.withTimeout(
      nanoseconds: 1_000_000_000,
      timeoutMessage: "should not time out"
    ) {
      "ok"
    }
    #expect(value == "ok")
  }

  @Test("withTimeout throws when the operation hangs past the deadline")
  func failsWhenOperationHangs() async throws {
    await #expect(throws: RemindCoreError.self) {
      try await AsyncTimeout.withTimeout(
        nanoseconds: 50_000_000,
        timeoutMessage: "Timed out geocoding location after 30s"
      ) {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        return "never"
      }
    }
  }
}
