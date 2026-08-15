import Darwin
import Foundation

public enum ProcessWait {
  public static let defaultTimeout: TimeInterval = 30

  public enum Error: Swift.Error, Equatable, LocalizedError {
    case timedOut(TimeInterval)

    public var errorDescription: String? {
      switch self {
      case .timedOut(let seconds):
        return "Timed out waiting for process after \(Int(seconds)) seconds"
      }
    }
  }

  public static func run(_ process: Process, seconds: TimeInterval = defaultTimeout) throws {
    let semaphore = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in
      semaphore.signal()
    }
    try process.run()
    if semaphore.wait(timeout: .now() + seconds) == .timedOut {
      process.terminate()
      if semaphore.wait(timeout: .now() + 2) == .timedOut {
        let pid = process.processIdentifier
        if pid > 0, process.isRunning {
          kill(pid, SIGKILL)
        }
        _ = semaphore.wait(timeout: .now() + 2)
      }
      throw Error.timedOut(seconds)
    }
  }
}
