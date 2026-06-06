import Foundation
import SwiftData

@Model
final class AppSettings {

    static let minIntervalMinutes = 30
    static let maxIntervalMinutes = 360
    static let defaultIntervalMinutes = 180

    private var storedIntervalMinutes: Int
    var remindersEnabled: Bool

    var reminderIntervalMinutes: Int {
        get { storedIntervalMinutes }
        set {
            storedIntervalMinutes = min(
                max(newValue, Self.minIntervalMinutes),
                Self.maxIntervalMinutes
            )
        }
    }

    init(reminderIntervalMinutes: Int = AppSettings.defaultIntervalMinutes,
         remindersEnabled: Bool = true) {
        self.storedIntervalMinutes = min(
            max(reminderIntervalMinutes, Self.minIntervalMinutes),
            Self.maxIntervalMinutes
        )
        self.remindersEnabled = remindersEnabled
    }

    @MainActor
    static func loadOrCreate(in context: ModelContext) throws -> AppSettings {
        let existing = try context.fetch(FetchDescriptor<AppSettings>())
        if let first = existing.first {
            return first
        }
        let new = AppSettings()
        context.insert(new)
        try context.save()
        return new
    }
}
