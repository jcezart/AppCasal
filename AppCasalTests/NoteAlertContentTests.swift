//
//  NoteAlertContentTests.swift
//  AppCasalTests
//

import CloudKit
import Foundation
import Testing
@testable import AppCasal

struct NoteAlertContentTests {
    private let me = "_me"
    private let partner = "_partner"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func note(_ text: String, by author: String, minutesAgo: Double, editedAfter: Double = 0, deleted: Bool = false) -> NoteAlertContent.Note {
        let created = now.addingTimeInterval(-minutesAgo * 60)
        return NoteAlertContent.Note(
            text: text,
            authorID: author,
            createdAt: created,
            modifiedAt: created.addingTimeInterval(editedAfter),
            deletedAt: deleted ? now : nil
        )
    }

    @Test func picksThePartnersLatestRecentNote() {
        let notes = [
            note("Antigo", by: partner, minutesAgo: 60),
            note("Bom dia, amor", by: partner, minutesAgo: 2),
            note("Oi", by: partner, minutesAgo: 5),
            note("Meu próprio", by: me, minutesAgo: 1),
        ]
        #expect(NoteAlertContent.latestFromPartner(notes, me: me, now: now)?.text == "Bom dia, amor")
    }

    @Test func ignoresOwnDeletedAndOldNotes() {
        let notes = [
            note("Meu", by: me, minutesAgo: 1),
            note("Apagado", by: partner, minutesAgo: 1, deleted: true),
            note("Velho", by: partner, minutesAgo: 30),
        ]
        #expect(NoteAlertContent.latestFromPartner(notes, me: me, now: now) == nil)
    }

    @Test func bodyIsTheTextMarkedWhenEditedAndClipped() {
        #expect(NoteAlertContent.body(for: note(" Te amo ", by: partner, minutesAgo: 1)) == "Te amo")
        #expect(NoteAlertContent.body(for: note("Te amo", by: partner, minutesAgo: 10, editedAfter: 300)) == String(localized: "Editado: \("Te amo")"))
        let long = NoteAlertContent.body(for: note(String(repeating: "a", count: 500), by: partner, minutesAgo: 1))
        #expect(long.count == NoteAlertContent.maximumBodyLength)
        #expect(long.hasSuffix("…"))
    }

    @Test func readsMirroredNoteRecordFields() {
        let record = CKRecord(recordType: NoteAlertContent.recordType)
        record["CD_text"] = "Saudade"
        record["CD_authorID"] = partner
        record["CD_createdAt"] = now
        let parsed = NoteAlertContent.note(from: record)
        #expect(parsed?.text == "Saudade")
        #expect(parsed?.authorID == partner)
        #expect(parsed?.modifiedAt == now)
        #expect(NoteAlertContent.note(from: CKRecord(recordType: "CD_Memory")) == nil)
    }

    @Test func subscriptionAsksForMutableContent() {
        #expect(NoteAlerts.makeSubscription(partnerName: "Lucas").notificationInfo?.shouldSendMutableContent == true)
        #expect(NoteAlerts.subscriptionID == NoteAlertContent.subscriptionID)
        #expect(NoteAlertContent.containerIdentifier == PersistenceController.cloudKitContainerIdentifier)
    }

    @Test func timestampNamesTheDayAndTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        let locale = Locale(identifier: "pt_BR")
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
        }
        let now = try date(2026, 10, 18, 20, 0)
        func text(_ value: Date) -> String { NoteTimestamp.text(for: value, now: now, calendar: calendar, locale: locale) }

        #expect(text(try date(2026, 10, 18, 14, 32)) == "Hoje às 14:32")
        #expect(text(try date(2026, 10, 17, 9, 5)) == "Ontem às 09:05")
        #expect(text(try date(2026, 10, 12, 14, 32)) == "12 de out. às 14:32")
        #expect(text(try date(2025, 10, 12, 14, 32)) == "12 de out. de 2025 às 14:32")
    }

    @Test func subtitleUsesTheEditTimeForEditedNotes() {
        let fresh = note("Oi", by: partner, minutesAgo: 30)
        let edited = note("Oi", by: partner, minutesAgo: 30, editedAfter: 20 * 60)
        #expect(NoteAlertContent.subtitle(for: fresh, now: now) == NoteTimestamp.text(for: fresh.createdAt, now: now))
        #expect(NoteAlertContent.subtitle(for: edited, now: now) == NoteTimestamp.text(for: edited.modifiedAt, now: now))
        #expect(NoteAlertContent.subtitle(for: edited, now: now) != NoteAlertContent.subtitle(for: fresh, now: now))
    }
}
