//
//  MomentsRules.swift
//  AppCasal
//

import Foundation

// MARK: - Quem conhece melhor?

/// A game question as frozen in a round: the catalog may change, the round does not.
nonisolated struct GameQuestionSnapshot: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let text: String
    let options: [CatalogGameOption]

    init(_ question: CatalogGameQuestion) {
        id = question.id
        text = question.text
        options = question.options
    }

    func option(withID id: String?) -> CatalogGameOption? {
        options.first { $0.id == id }
    }
}

/// One partner's answer to one question: about themselves and a guess about the partner.
/// Nil means skipped (no option fit).
nonisolated struct GameEntry: Codable, Equatable, Sendable {
    let questionID: String
    var selfOptionID: String?
    var guessOptionID: String?
}

nonisolated struct GameScore: Equatable, Sendable {
    /// Guesses that matched the partner's own choice.
    var correct: Int
    /// Questions where both the guess and the partner's choice exist.
    var compared: Int
}

nonisolated enum GameRules {
    static let roundSize = 5

    /// `roundSize` distinct questions: never used before first, then the least recently used.
    /// `recentlyUsed` lists question IDs from older to newer rounds.
    static func pickQuestions<Generator: RandomNumberGenerator>(
        from questions: [CatalogGameQuestion],
        recentlyUsed: [String],
        using generator: inout Generator
    ) -> [CatalogGameQuestion] {
        var lastUse: [String: Int] = [:]
        for (index, id) in recentlyUsed.enumerated() {
            lastUse[id] = index
        }
        // Shuffle first so ties are not always broken by catalog order.
        let shuffled = questions.shuffled(using: &generator)
        let ordered = shuffled.sorted { (lastUse[$0.id] ?? -1) < (lastUse[$1.id] ?? -1) }
        return Array(ordered.prefix(roundSize))
    }

    /// How well `guesser` guessed `chooser`. Compared by question and option IDs, never by
    /// text or position. Skipped questions are left out of `compared`.
    static func score(guesser: [GameEntry], chooser: [GameEntry]) -> GameScore {
        let choices = Dictionary(chooser.map { ($0.questionID, $0.selfOptionID) }, uniquingKeysWith: { first, _ in first })
        var score = GameScore(correct: 0, compared: 0)
        for entry in guesser {
            guard let guess = entry.guessOptionID, let choice = choices[entry.questionID] ?? nil else { continue }
            score.compared += 1
            if guess == choice { score.correct += 1 }
        }
        return score
    }

    static func encode<T: Encodable>(_ value: T) -> String? {
        (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static func decode<T: Decodable>(_ type: T.Type, from json: String?) -> T? {
        guard let data = json?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Pequeno gesto

nonisolated enum GestureRules {
    /// Gestures not suggested again soon.
    static let recentLimit = 30

    static func next<Generator: RandomNumberGenerator>(
        from gestures: [CatalogGesture],
        recent: [String],
        excluding current: String? = nil,
        using generator: inout Generator
    ) -> CatalogGesture? {
        let recentSet = Set(recent.suffix(recentLimit))
        let fresh = gestures.filter { !recentSet.contains($0.id) && $0.id != current }
        return (fresh.isEmpty ? gestures.filter { $0.id != current } : fresh).randomElement(using: &generator)
    }
}

// MARK: - Vamos reviver?

nonisolated struct ReviveCandidate: Equatable, Sendable {
    let id: UUID
    /// The day the memory happened (date picker precision: a day).
    let date: Date
}

nonisolated struct ReviveSuggestion: Equatable, Sendable {
    let id: UUID
    /// Whole years since the memory, when today is its anniversary.
    let yearsAgo: Int?
}

nonisolated enum ReviveRules {
    /// A memory from less than this many days ago is not offered as "revive".
    static let minimumAgeDays = 30
    static let recentLimit = 10

    /// Today's anniversary first (at least one full year ago; a 29 February memory is
    /// remembered on 28 February in common years). Otherwise the oldest memory not
    /// suggested recently and at least `minimumAgeDays` old.
    static func suggestion(
        from memories: [ReviveCandidate],
        recent: [UUID],
        today: Date,
        calendar: Calendar
    ) -> ReviveSuggestion? {
        let todayParts = calendar.dateComponents([.year, .month, .day], from: today)
        let isLeap = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: todayParts.year, month: 2)) ?? today)?.count == 29
        let anniversaries = memories.compactMap { memory -> (ReviveCandidate, Int)? in
            let parts = calendar.dateComponents([.year, .month, .day], from: memory.date)
            guard let year = parts.year, let thisYear = todayParts.year, year < thisYear else { return nil }
            var day = parts.day
            if parts.month == 2, day == 29, !isLeap {
                day = 28
            }
            guard parts.month == todayParts.month, day == todayParts.day else { return nil }
            return (memory, thisYear - year)
        }
        if let (memory, years) = anniversaries.min(by: { $0.0.date < $1.0.date }) {
            return ReviveSuggestion(id: memory.id, yearsAgo: years)
        }
        let recentSet = Set(recent.suffix(recentLimit))
        let threshold = calendar.date(byAdding: .day, value: -minimumAgeDays, to: calendar.startOfDay(for: today)) ?? today
        let old = memories.filter { $0.date <= threshold }.sorted { $0.date < $1.date }
        let pick = old.first { !recentSet.contains($0.id) } ?? old.first
        return pick.map { ReviveSuggestion(id: $0.id, yearsAgo: nil) }
    }
}
