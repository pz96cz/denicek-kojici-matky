import Testing
import Foundation
import SwiftData
@testable import Kojeni

@Suite @MainActor
struct AppSettingsTests {

    @Test func default_values() {
        let settings = AppSettings()
        #expect(settings.reminderIntervalMinutes == 180)
        #expect(settings.remindersEnabled)
    }

    @Test func custom_values_in_range() {
        let settings = AppSettings(reminderIntervalMinutes: 120, remindersEnabled: false)
        #expect(settings.reminderIntervalMinutes == 120)
        #expect(!settings.remindersEnabled)
    }

    @Test func interval_below_minimum_is_clamped() {
        let settings = AppSettings(reminderIntervalMinutes: 10)
        #expect(settings.reminderIntervalMinutes == 30, "Below-min should clamp to 30")
    }

    @Test func interval_above_maximum_is_clamped() {
        let settings = AppSettings(reminderIntervalMinutes: 9999)
        #expect(settings.reminderIntervalMinutes == 360, "Above-max should clamp to 360")
    }

    @Test func loadOrCreate_returns_existing() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)
        let existing = AppSettings(reminderIntervalMinutes: 240)
        context.insert(existing)
        try context.save()

        let loaded = try AppSettings.loadOrCreate(in: context)

        #expect(loaded.reminderIntervalMinutes == 240)
        let count = try context.fetch(FetchDescriptor<AppSettings>()).count
        #expect(count == 1)
    }

    @Test func loadOrCreate_creates_with_defaults_when_missing() throws {
        let container = InMemoryContainer.make()
        let context = ModelContext(container)

        let loaded = try AppSettings.loadOrCreate(in: context)

        #expect(loaded.reminderIntervalMinutes == 180)
        #expect(loaded.remindersEnabled)
        let count = try context.fetch(FetchDescriptor<AppSettings>()).count
        #expect(count == 1)
    }
}
