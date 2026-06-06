import Foundation

extension FeedingSession {

    func segments() -> [(breast: Breast, start: Date, end: Date)] {
        let sortedChanges = breastChanges.sorted { $0.at < $1.at }
        let sessionEnd = endedAt ?? .now

        var result: [(breast: Breast, start: Date, end: Date)] = []
        var currentStart = startedAt
        var currentBreast = initialBreast

        for change in sortedChanges {
            result.append((breast: currentBreast, start: currentStart, end: change.at))
            currentStart = change.at
            currentBreast = change.to
        }
        result.append((breast: currentBreast, start: currentStart, end: sessionEnd))

        return result
    }
}
