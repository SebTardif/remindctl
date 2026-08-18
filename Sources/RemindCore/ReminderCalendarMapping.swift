import Foundation

enum ReminderCalendarMapping {
  /// EventKit's `EKReminder.calendar` is an IUO. A nil calendar means the
  /// reminder is orphaned; callers should skip that row instead of unwrapping.
  static func listIdentity(calendarIdentifier: String?, title: String?) -> ReminderList? {
    guard let calendarIdentifier else { return nil }
    return ReminderList(id: calendarIdentifier, title: title ?? "")
  }
}
