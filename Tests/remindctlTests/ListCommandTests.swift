import Testing

@testable import RemindCore
@testable import remindctl

@MainActor
struct ListCommandTests {
  @Test("Multiple list names are allowed for read-only listing")
  func multipleNamesAllowedForListing() throws {
    let name = try ListCommand.singleListName(["Work", "Home"], forMutation: false)
    #expect(name == "Work")
  }

  @Test("Multiple list names are rejected for mutations")
  func multipleNamesRejectedForMutations() {
    #expect(throws: Error.self) {
      _ = try ListCommand.singleListName(["Work", "Home"], forMutation: true)
    }
  }

  @Test("Multiple list names keep read-only multi-list behavior")
  func multipleNamesUseMultiListReadOnlyPath() {
    #expect(ListCommand.shouldReadMultipleLists(names: ["Work", "Home"], listID: nil, isMutation: false))
    #expect(!ListCommand.shouldReadMultipleLists(names: ["Work", "Home"], listID: nil, isMutation: true))
    #expect(!ListCommand.shouldReadMultipleLists(names: ["Work", "Home"], listID: "LIST", isMutation: false))
  }

  @Test("Open command keeps list-constrained filter behavior")
  func openListWithoutAppShowsOpenReminders() {
    #expect(OpenCommand.shouldShowOpenReminders(id: nil, listName: "Work", listID: nil, app: false))
    #expect(OpenCommand.shouldShowOpenReminders(id: nil, listName: nil, listID: "LIST", app: false))
    #expect(!OpenCommand.shouldShowOpenReminders(id: nil, listName: "Work", listID: nil, app: true))
    #expect(!OpenCommand.shouldShowOpenReminders(id: "A123", listName: nil, listID: nil, app: false))
  }

  @Test("Create plans a new list when no matching list exists")
  func createPlansNewListWhenMissing() throws {
    let lists = [
      ReminderList(id: "AAAA-1111", title: "Work")
    ]
    #expect(try ListCommand.existingListForCreate(name: "Projects", lists: lists) == nil)
  }

  @Test("Create reuses a unique existing list instead of inserting another")
  func createReusesUniqueExistingList() throws {
    let existing = ReminderList(id: "AAAA-1111", title: "Projects")
    #expect(try ListCommand.existingListForCreate(name: "Projects", lists: [existing]) == existing)
  }

  @Test("Create reuses a unique case-insensitive match")
  func createReusesCaseInsensitiveMatch() throws {
    let existing = ReminderList(id: "AAAA-1111", title: "Projects")
    #expect(try ListCommand.existingListForCreate(name: "projects", lists: [existing]) == existing)
  }

  @Test("Create rejects an already-ambiguous list name")
  func createRejectsAmbiguousExistingName() {
    let lists = [
      ReminderList(id: "AAAA-1111", title: "Projects"),
      ReminderList(id: "BBBB-2222", title: "Projects"),
    ]
    #expect(throws: RemindCoreError.self) {
      _ = try ListCommand.existingListForCreate(name: "Projects", lists: lists)
    }
  }
}
