import Foundation
import RemindCore

struct RichReadDiagnostics: Codable, Sendable, Equatable {
  let storeDirectory: String
  let databasePath: String?
  let readable: Bool
  let tableCounts: [String: Int]
  let error: String?

  static func collect() -> RichReadDiagnostics {
    let storeDir = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Group Containers/group.com.apple.reminders/Container_v1/Stores")
    let db = findDatabase(in: storeDir)
    guard let db else {
      return RichReadDiagnostics(
        storeDirectory: storeDir.path,
        databasePath: nil,
        readable: FileManager.default.isReadableFile(atPath: storeDir.path),
        tableCounts: [:],
        error: "No Data-*.sqlite store found"
      )
    }
    guard FileManager.default.isReadableFile(atPath: db.path) else {
      return RichReadDiagnostics(
        storeDirectory: storeDir.path,
        databasePath: db.path,
        readable: false,
        tableCounts: [:],
        error: "Reminders database is not readable from this process"
      )
    }

    var counts: [String: Int] = [:]
    var errors: [String] = []
    for (name, sql) in [
      ("tags", "SELECT COUNT(*) FROM ZREMCDHASHTAGLABEL;"),
      ("sections", "SELECT COUNT(*) FROM ZREMCDBASESECTION WHERE COALESCE(ZMARKEDFORDELETION, 0) = 0;"),
      ("subtasks", "SELECT COUNT(*) FROM ZREMCDREMINDER WHERE ZPARENTREMINDER IS NOT NULL;"),
      ("smartLists", "SELECT COUNT(*) FROM ZREMCDBASELIST WHERE Z_ENT = 4 AND COALESCE(ZMARKEDFORDELETION, 0) = 0;"),
    ] {
      do {
        counts[name] = try sqliteCount(database: db, sql: sql)
      } catch {
        errors.append("\(name): \(error.localizedDescription)")
      }
    }

    return RichReadDiagnostics(
      storeDirectory: storeDir.path,
      databasePath: db.path,
      readable: true,
      tableCounts: counts,
      error: errors.isEmpty ? nil : errors.joined(separator: "; ")
    )
  }

  private static func findDatabase(in directory: URL) -> URL? {
    guard
      let urls = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles]
      )
    else { return nil }
    return
      urls
      .filter { $0.lastPathComponent.hasPrefix("Data-") && $0.pathExtension == "sqlite" }
      .max { lhs, rhs in
        size(lhs) < size(rhs)
      }
  }

  private static func size(_ url: URL) -> Int {
    ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
  }

  private static func sqliteCount(database: URL, sql: String) throws -> Int {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = ["-readonly", database.path, sql]
    let output = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = output
    process.standardError = errorPipe
    try ProcessWait.run(process)
    let data = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
      let message = String(data: errorData, encoding: .utf8) ?? "sqlite3 failed"
      throw NSError(
        domain: "sqlite3", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
    }
    let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return Int(text) ?? 0
  }
}
