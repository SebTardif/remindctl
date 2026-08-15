import Foundation
import Testing

@testable import RemindCore

struct ProcessWaitTests {
  @Test("Returns when the process exits before the deadline")
  func processWins() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try ProcessWait.run(process, seconds: 5)
    #expect(process.terminationStatus == 0)
    #expect(!process.isRunning)
  }

  @Test("Terminates a stuck process and throws a timeout error")
  func timeoutTerminatesProcess() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sleep")
    process.arguments = ["60"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try ProcessWait.run(process, seconds: 0.5)
      Issue.record("expected timeout")
    } catch let error as ProcessWait.Error {
      #expect(error == .timedOut(0.5))
    }
    #expect(!process.isRunning)
  }

  @Test("Force-stops a process that ignores SIGTERM")
  func timeoutForceStopsTermIgnoringProcess() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
    process.arguments = ["-e", "$SIG{TERM}='IGNORE'; sleep 60"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try ProcessWait.run(process, seconds: 0.5)
      Issue.record("expected timeout")
    } catch let error as ProcessWait.Error {
      #expect(error == .timedOut(0.5))
    }
    #expect(!process.isRunning)
  }
}
