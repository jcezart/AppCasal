//
//  DemoData.swift
//  AppCasal
//

#if DEBUG
import Foundation

/// Fictitious data for previews and the demo configuration only. Uses the
/// production repositories, so demo screens exercise the real code paths.
/// Written to its own store files, never to the real (CloudKit) stores.
enum DemoData {
    static let ownerID = "demo.owner"
    static let partnerID = "demo.partner"

    /// Separate from the production stores in `NSPersistentContainer.defaultDirectoryURL()`.
    static var storeDirectory: URL {
        let directory = URL.applicationSupportDirectory.appending(path: "DemoStores", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Seeds a couple space with notes when the demo store is empty.
    static func seedIfNeeded(_ environment: AppEnvironment, now: Date = .now) throws {
        precondition(environment.runMode != .production, "Demo data must never reach the real stores")
        guard environment.spaces.activeSpace() == nil else { return }

        let calendar = Calendar.current
        let space = try environment.spaces.createSpace(ownerName: "Ana", userRecordName: ownerID, now: now)
        try environment.spaces.setRelationshipStart(calendar.date(byAdding: .day, value: -842, to: now), in: space)
        let partner = try environment.spaces.ensureMember(named: "Lucas", userRecordName: partnerID, in: space, now: now)
        partner.role = Member.Role.participant.rawValue

        let notes: [(String, String, Int)] = [
            ("Mal posso esperar pelos nossos próximos capítulos.", partnerID, -9 * 24 * 60),
            ("Você torna os dias comuns muito mais especiais. Obrigada por estar sempre aqui.", ownerID, -26 * 60),
            ("Seu sorriso é minha parte favorita do dia.", partnerID, -35),
        ]
        for (text, author, minutes) in notes {
            try environment.notes.create(text: text, in: space, by: author, now: now.addingTimeInterval(TimeInterval(minutes * 60)))
        }
    }

    /// In-memory environment with demo data, for SwiftUI previews.
    static func previewEnvironment() -> AppEnvironment {
        let environment = AppEnvironment(runMode: .preview)
        try? seedIfNeeded(environment)
        return environment
    }
}
#endif
