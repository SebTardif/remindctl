import EventKit
import Foundation
import Testing

@testable import RemindCore

@MainActor
struct ReminderSnapshotTests {
  @Test("A real EventKit reminder without a calendar is skipped")
  func skipsMissingCalendar() throws {
    let reminder = EKReminder(eventStore: EKEventStore())
    reminder.title = "Orphan"
    try #require(reminder.calendar == nil)

    #expect(RemindersStore.reminderData(from: reminder) == nil)
  }

  @Test("Fetched snapshots preserve valid reminders around a missing calendar")
  func preservesValidReminders() throws {
    let store = EKEventStore()
    let calendar = EKCalendar(for: .reminder, eventStore: store)
    calendar.title = "Synthetic list"
    let first = EKReminder(eventStore: store)
    first.calendar = calendar
    first.title = "First"
    first.notes = "Synthetic notes"
    first.url = URL(string: "https://example.com/reminder")
    first.priority = 1
    first.dueDateComponents = DateComponents(year: 2026, month: 8, day: 30)
    let alarmDate = Date(timeIntervalSince1970: 1_700_000_000)
    first.addAlarm(EKAlarm(absoluteDate: alarmDate))
    first.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil))
    let orphan = EKReminder(eventStore: store)
    orphan.title = "Orphan"
    try #require(orphan.calendar == nil)
    let last = EKReminder(eventStore: store)
    last.calendar = calendar
    last.title = "Last"

    let snapshots = [first, orphan, last].compactMap(RemindersStore.reminderData(from:))

    #expect(snapshots.map(\.id) == [first.calendarItemIdentifier, last.calendarItemIdentifier])
    #expect(snapshots.map(\.title) == ["First", "Last"])
    #expect(snapshots.map(\.listID) == [calendar.calendarIdentifier, calendar.calendarIdentifier])
    #expect(snapshots.map(\.listName) == ["Synthetic list", "Synthetic list"])
    let snapshot = try #require(snapshots.first)
    #expect(snapshot.notes == first.notes)
    #expect(snapshot.url == first.url)
    #expect(!snapshot.isCompleted)
    #expect(snapshot.priority == 1)
    #expect(snapshot.dueDateComponents == first.dueDateComponents)
    #expect(snapshot.dueDateIsAllDay)
    #expect(snapshot.alarmDate == alarmDate)
    #expect(snapshot.recurrenceRule == RecurrenceRule(frequency: .weekly, interval: 2))
  }

  @Test("Mutation mapping errors instead of trapping when calendar is missing")
  func mutationMappingErrorsOnMissingCalendar() throws {
    let reminder = EKReminder(eventStore: EKEventStore())
    reminder.title = "Orphan"
    try #require(reminder.calendar == nil)

    #expect(throws: RemindCoreError.operationFailed("Reminder is missing a calendar")) {
      _ = try RemindersStore.reminderItem(from: reminder)
    }
  }

  @Test("Mutation mapping keeps list identity for a reminder with a calendar")
  func mutationMappingPreservesCalendar() throws {
    let store = EKEventStore()
    let calendar = EKCalendar(for: .reminder, eventStore: store)
    calendar.title = "Synthetic list"
    let reminder = EKReminder(eventStore: store)
    reminder.calendar = calendar
    reminder.title = "Keep me"
    reminder.notes = "Synthetic notes"
    reminder.priority = 5

    let item = try RemindersStore.reminderItem(from: reminder)

    #expect(item.id == reminder.calendarItemIdentifier)
    #expect(item.title == "Keep me")
    #expect(item.notes == "Synthetic notes")
    #expect(item.priority == .medium)
    #expect(item.listID == calendar.calendarIdentifier)
    #expect(item.listName == "Synthetic list")
    #expect(!item.isCompleted)
  }
}
