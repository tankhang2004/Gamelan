import Foundation

/// One finished run.
struct ScoreRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let score: Int
    let survivedSeconds: Double
    let date: Date

    init(id: UUID = UUID(), score: Int, survivedSeconds: Double, date: Date = .now) {
        self.id = id
        self.score = score
        self.survivedSeconds = survivedSeconds
        self.date = date
    }
}

/// Persistence seam for past runs, so previews and tests can swap in memory.
protocol ScoreHistoryStoring: AnyObject {
    var records: [ScoreRecord] { get }
    func record(_ record: ScoreRecord)
}

extension ScoreHistoryStoring {
    var best: ScoreRecord? { records.max { $0.score < $1.score } }
}

/// Stores past runs as JSON in `UserDefaults`. Works with no network and no
/// GameKit, which is why it is built before the leaderboard rather than after.
final class UserDefaultsScoreHistoryStore: ScoreHistoryStoring {
    /// Older runs past this point are dropped; the list is a personal-best
    /// board, not an archive.
    private static let limit = 50

    private let defaults: UserDefaults
    private let key = "com.yuknari.scoreHistory"

    private(set) var records: [ScoreRecord]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let data = defaults.data(forKey: key) ?? Data()
        records = (try? JSONDecoder().decode([ScoreRecord].self, from: data)) ?? []
    }

    func record(_ record: ScoreRecord) {
        records = (records + [record])
            .sorted { $0.date > $1.date }
            .prefix(Self.limit)
            .map { $0 }

        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Non-persisting store for previews and tests.
final class InMemoryScoreHistoryStore: ScoreHistoryStoring {
    private(set) var records: [ScoreRecord]

    init(records: [ScoreRecord] = []) {
        self.records = records
    }

    func record(_ record: ScoreRecord) {
        records.insert(record, at: 0)
    }
}
