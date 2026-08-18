import Testing

@testable import RemindCore

struct ReminderCalendarMappingTests {
  @Test("A missing calendar identifier is skipped")
  func skipsMissingCalendar() {
    #expect(ReminderCalendarMapping.listIdentity(calendarIdentifier: nil, title: "Home") == nil)
    #expect(ReminderCalendarMapping.listIdentity(calendarIdentifier: nil, title: nil) == nil)
  }

  @Test("A present calendar maps list id and title")
  func mapsPresentCalendar() {
    #expect(
      ReminderCalendarMapping.listIdentity(calendarIdentifier: "CAL-1", title: "Home")
        == ReminderList(id: "CAL-1", title: "Home")
    )
    #expect(
      ReminderCalendarMapping.listIdentity(calendarIdentifier: "CAL-1", title: nil)
        == ReminderList(id: "CAL-1", title: "")
    )
  }

  @Test("Reminder rows with a missing calendar are dropped")
  func dropsRowsWithMissingCalendar() {
    let rows: [(calendarIdentifier: String?, title: String?)] = [
      ("CAL-1", "Home"),
      (nil, "Orphan"),
      ("CAL-2", "Work"),
    ]

    let kept = rows.compactMap { row in
      ReminderCalendarMapping.listIdentity(calendarIdentifier: row.calendarIdentifier, title: row.title)
    }

    #expect(kept == [ReminderList(id: "CAL-1", title: "Home"), ReminderList(id: "CAL-2", title: "Work")])
  }
}
