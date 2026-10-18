//
//  DemoData.swift
//  AppCasal
//

#if DEBUG
import Foundation
import UIKit

/// Fictitious data for previews and the demo configuration only. Uses the
/// production repositories, so demo screens exercise the real code paths.
/// Written to its own store files, never to the real (CloudKit) stores.
enum DemoData {
    static let ownerID = "demo.owner"
    static let partnerID = "demo.partner"

    /// Separate from the production stores in `NSPersistentContainer.defaultDirectoryURL()`.
    /// `-AppCasalDemoReset YES` starts from an empty demo store (UI tests).
    static let storeDirectory: URL = {
        let directory = URL.applicationSupportDirectory.appending(path: "DemoStores", directoryHint: .isDirectory)
        if UserDefaults.standard.bool(forKey: "AppCasalDemoReset") {
            try? FileManager.default.removeItem(at: directory)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    /// `-AppCasalDemoEmpty YES`: demo identity and space without fictitious content (UI tests).
    static var seedsContent: Bool {
        !UserDefaults.standard.bool(forKey: "AppCasalDemoEmpty")
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
        try environment.persistence.save()
        guard seedsContent else { return }

        let notes: [(String, String, Int)] = [
            ("Mal posso esperar pelos nossos próximos capítulos.", partnerID, -9 * 24 * 60),
            ("Você torna os dias comuns muito mais especiais. Obrigada por estar sempre aqui.", ownerID, -26 * 60),
            ("Seu sorriso é minha parte favorita do dia.", partnerID, -35),
        ]
        for (text, author, minutes) in notes {
            try environment.notes.create(text: text, in: space, by: author, now: now.addingTimeInterval(TimeInterval(minutes * 60)))
        }

        let memories: [(String, String, MemoryCategory, Int, [UIColor])] = [
            ("O primeiro encontro", "Café, boas conversas e um monte de planos.", .date, -12,
             [UIColor(red: 0.55, green: 0.33, blue: 0.24, alpha: 1), UIColor(red: 0.93, green: 0.78, blue: 0.62, alpha: 1)]),
            ("Nosso fim de tarde", "Um pôr do sol que vou guardar sempre na memória.", .beach, -5,
             [UIColor(red: 0.96, green: 0.62, blue: 0.38, alpha: 1), UIColor(red: 0.42, green: 0.36, blue: 0.52, alpha: 1)]),
        ]
        // Places around a fictitious beach town (Florianópolis area coordinates).
        let beach = try environment.places.create(
            PlaceDraft(name: "Praia da Joaquina", address: "Florianópolis", latitude: -27.6292, longitude: -48.4486, category: .beach, status: .visited),
            in: space, by: ownerID, now: now
        )
        let cafe = try environment.places.create(
            PlaceDraft(name: "Café do Centro", address: "Centro, Florianópolis", latitude: -27.5954, longitude: -48.5480, category: .restaurant, status: .visited),
            in: space, by: partnerID, now: now
        )
        try environment.places.create(
            PlaceDraft(name: "Mirante da Lagoa", address: "Lagoa da Conceição", latitude: -27.6005, longitude: -48.4719, category: .special, status: .wishlist, note: "Para ver o pôr do sol."),
            in: space, by: ownerID, now: now
        )
        try environment.places.create(
            PlaceDraft(name: "Ilha do Campeche", address: "Florianópolis", latitude: -27.6964, longitude: -48.4669, category: .trip, status: .wishlist),
            in: space, by: partnerID, now: now
        )

        for (title, details, category, days, colors) in memories {
            let date = calendar.date(byAdding: .day, value: days, to: now) ?? now
            let photo = try PhotoProcessing.processSynchronously(placeholderPhoto(colors))
            let place = category == .beach ? beach : cafe
            var draft = MemoryDraft(title: title, details: details, date: date, category: category)
            draft.place = PlaceLink(placeID: place.id, name: place.name ?? "", latitude: place.latitude, longitude: place.longitude)
            let memory = try environment.memories.create(draft, photos: [photo], in: space, by: days < -7 ? ownerID : partnerID, now: date)
            try environment.places.markVisited(place, memoryID: memory.id, on: date, by: ownerID, now: date)
        }

        var trip = GoalDraft(title: "Nossa próxima viagem", category: .trip)
        trip.dueDate = calendar.date(byAdding: .month, value: 2, to: now)
        trip.steps = ["Escolher o destino", "Pesquisar passagens", "Reservar a hospedagem", "Montar o roteiro", "Comprar os ingressos"].map { .init(title: $0) }
        let tripGoal = try environment.goals.create(trip, in: space, by: ownerID, now: now)
        for step in tripGoal.visibleSteps.prefix(3) {
            try environment.goals.toggle(step, by: partnerID, now: now)
        }
        var dates = GoalDraft(title: "Mais encontros a dois", category: .relationship)
        dates.steps = ["Planejar um jantar especial", "Fazer uma noite de filmes em casa", "Conhecer um lugar novo na cidade"].map { .init(title: $0) }
        let datesGoal = try environment.goals.create(dates, in: space, by: partnerID, now: now)
        if let first = datesGoal.visibleSteps.first {
            try environment.goals.toggle(first, by: ownerID, now: now)
        }
        let finished = try environment.goals.create(GoalDraft(title: "Adotar uma plantinha", category: .home), in: space, by: ownerID, now: now)
        try environment.goals.complete(finished, by: ownerID, now: calendar.date(byAdding: .day, value: -20, to: now) ?? now)

        if let favoriteID = space.notes?.first(where: { $0.authorID == partnerID })?.id {
            try environment.favorites.toggle(noteID: favoriteID, for: ownerID, now: now)
        }
        let cover = try PhotoProcessing.processSynchronously(placeholderPhoto([
            UIColor(red: 0.96, green: 0.74, blue: 0.56, alpha: 1), UIColor(red: 0.62, green: 0.42, blue: 0.40, alpha: 1),
        ]))
        try environment.spaces.setCoverPhoto(cover.imageData, in: space)

        if let start = space.relationshipStart {
            try environment.reminders.create(
                ReminderDraft(title: "Aniversário de namoro", date: start, daysBefore: 3, notifies: false, repetition: .yearly),
                in: space, by: ownerID, now: now
            )
        }
        try seedMoments(environment, space: space, now: now)
    }

    /// "Hoje, nós dois": today's question already answered by the partner, one own idea,
    /// a memory from a year ago (its anniversary is today) for "Vamos reviver?".
    private static func seedMoments(_ environment: AppEnvironment, space: CoupleSpace, now: Date) throws {
        guard case .success(let catalog) = environment.catalog else { return }
        try environment.moments.prepareDays(in: space, questions: catalog.questions, catalogVersion: catalog.questionsVersion, by: ownerID, now: now)
        if let key = environment.moments.todayKey(in: space, now: now), let session = environment.moments.session(for: key, in: space) {
            try environment.moments.submitAnswer("Acho que seria “Dois perdidos no supermercado”.", to: session, by: partnerID, now: now)
        }
        try environment.moments.createIdea(
            DateIdeaDraft(title: "Noite de fondue", details: "Fondue em casa com a playlist do nosso primeiro ano.", location: .casa, cost: .baixo, durationMinutes: 120),
            in: space, by: partnerID, now: now
        )
        let calendar = Calendar.current
        let lastYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let photo = try PhotoProcessing.processSynchronously(placeholderPhoto([
            UIColor(red: 0.42, green: 0.56, blue: 0.68, alpha: 1), UIColor(red: 0.95, green: 0.84, blue: 0.70, alpha: 1),
        ]))
        var picnic = MemoryDraft(title: "Piquenique no parque", details: "Sanduíches, sol e uma tarde inteira de conversa.", date: lastYear, category: .date)
        picnic.place = PlaceLink(placeID: nil, name: "Parque da Luz", latitude: -27.5867, longitude: -48.5531)
        try environment.memories.create(picnic, photos: [photo], in: space, by: ownerID, now: lastYear)
    }

    /// Fictitious "photo": a warm gradient with a sun. Demo and previews only.
    static func placeholderPhoto(_ colors: [UIColor]) -> Data {
        let size = CGSize(width: 1200, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size, format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }())
        return renderer.jpegData(withCompressionQuality: 0.9) { context in
            let cg = context.cgContext
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            UIColor(white: 1, alpha: 0.35).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.62, y: size.height * 0.22, width: 220, height: 220))
            UIColor(white: 0, alpha: 0.18).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.78, width: size.width, height: size.height * 0.22))
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
