//
//  DailyQuestionPlanner.swift
//  AppCasal
//

import Foundation

/// Calendar days of "Hoje, nós dois", independent of each device's time zone.
///
/// Rules: the day is the Gregorian date in the space's `momentsTimeZone` (set once by the
/// owner). It turns at local midnight there; daylight saving time only changes the length
/// of a day, never its key. A partner in another time zone sees the space's day. A device
/// with a wrong clock computes another key and, when that day was not prepared, shows the
/// question as unavailable instead of inventing one.
nonisolated enum MomentsCalendar {
    static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// "yyyy-MM-dd".
    static func dayKey(for date: Date, in timeZone: TimeZone) -> String {
        let components = calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// Start of the day `key` in `timeZone`.
    static func date(forDayKey key: String, in timeZone: TimeZone) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar(in: timeZone).date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// `count` consecutive day keys starting at the day of `date`.
    static func dayKeys(startingAt date: Date, count: Int, in timeZone: TimeZone) -> [String] {
        let calendar = calendar(in: timeZone)
        let start = calendar.startOfDay(for: date)
        return (0..<max(count, 0)).compactMap { offset in
            // Noon avoids landing on the previous day around DST changes.
            calendar.date(byAdding: DateComponents(day: offset, hour: 12), to: start).map { dayKey(for: $0, in: timeZone) }
        }
    }
}

/// A question already given to a day (from a `DailyQuestion`).
nonisolated struct QuestionAssignment: Equatable, Sendable {
    var dayKey: String
    var questionID: String
    var cycle: Int
}

/// Chooses the questions of the days still without one. Deterministic: the same history
/// and catalog always give the same plan, on any device and app version with that catalog.
///
/// Order: themes keep alternating (the category after the last assigned one, in the
/// catalog's category order); within a theme, the first question in catalog order not used
/// in the current cycle. When every question was used, a new cycle starts; past answers stay.
nonisolated enum DailyQuestionPlanner {
    /// Days prepared ahead by the owner, so the partner has the question offline too.
    static let daysAhead = 14

    static func plan(
        days: [String],
        existing: [QuestionAssignment],
        questions: [CatalogQuestion],
        categoryOrder: [QuestionCategory] = QuestionCategory.allCases
    ) -> [(dayKey: String, question: CatalogQuestion, cycle: Int)] {
        guard !questions.isEmpty else { return [] }
        let assignedDays = Set(existing.map(\.dayKey))
        var history = existing.sorted { $0.dayKey < $1.dayKey }
        var result: [(dayKey: String, question: CatalogQuestion, cycle: Int)] = []
        for day in days.sorted() where !assignedDays.contains(day) {
            // A day before the last assigned one is never filled retroactively.
            if let last = history.last, day < last.dayKey { continue }
            let (question, cycle) = next(after: history, questions: questions, categoryOrder: categoryOrder)
            result.append((day, question, cycle))
            history.append(QuestionAssignment(dayKey: day, questionID: question.id, cycle: cycle))
        }
        return result
    }

    static func next(
        after history: [QuestionAssignment],
        questions: [CatalogQuestion],
        categoryOrder: [QuestionCategory] = QuestionCategory.allCases
    ) -> (CatalogQuestion, Int) {
        var cycle = history.map(\.cycle).max() ?? 0
        var used = Set(history.filter { $0.cycle == cycle }.map(\.questionID))
        let catalogIDs = Set(questions.map(\.id))
        if catalogIDs.isSubset(of: used) {
            cycle += 1
            used = []
        }
        let lastCategory = history.last.flatMap { last in questions.first { $0.id == last.questionID }?.category }
        let startIndex = lastCategory.flatMap { categoryOrder.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        for offset in 0..<categoryOrder.count {
            let category = categoryOrder[(startIndex + offset) % categoryOrder.count]
            if let question = questions.first(where: { $0.category == category && !used.contains($0.id) }) {
                return (question, cycle)
            }
        }
        // Categories outside `categoryOrder` (a future catalog): plain catalog order.
        let question = questions.first { !used.contains($0.id) } ?? questions[0]
        return (question, cycle)
    }
}

/// Picks one record when sync produced several for the same key (two devices created the
/// same day or round offline). Earliest creation wins, then the smallest ID, so every
/// device agrees without deleting anything.
nonisolated enum Canonical {
    static func pick<T>(_ items: [T], createdAt: (T) -> Date?, id: (T) -> UUID?) -> T? {
        items.min { lhs, rhs in
            let left = createdAt(lhs) ?? .distantFuture
            let right = createdAt(rhs) ?? .distantFuture
            if left != right { return left < right }
            return (id(lhs)?.uuidString ?? "~") < (id(rhs)?.uuidString ?? "~")
        }
    }
}
