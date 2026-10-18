//
//  NoteTimestamp.swift
//  AppCasal
//
//  Compiled in the app and in the NoteNotificationService extension.
//

import Foundation

/// Day and time of a note, as shown on its card and in its alert:
/// "Hoje às 14:32", "Ontem às 09:05", "12 de out. às 14:32", "12 de out. de 2025 às 14:32".
nonisolated enum NoteTimestamp {
    static func text(
        for date: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        var calendar = calendar
        calendar.locale = locale
        let time = date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute())
        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "Hoje às \(time)")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Ontem às \(time)")
        }
        var dayStyle = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        if !calendar.isDate(date, equalTo: now, toGranularity: .year) {
            dayStyle = dayStyle.year()
        }
        return String(localized: "\(date.formatted(dayStyle)) às \(time)")
    }
}
