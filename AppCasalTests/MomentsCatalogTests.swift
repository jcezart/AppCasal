//
//  MomentsCatalogTests.swift
//  AppCasalTests
//

import CoreData
import Foundation
import Testing
@testable import AppCasal

/// The shipped catalog and the model migration of "Hoje, nós dois".
struct MomentsCatalogTests {
    @Test func catalogHasEveryItemWithUniqueIDs() throws {
        let catalog = try MomentsCatalog.load()
        #expect(catalog.questions.count == 365)
        #expect(catalog.dates.count == 100)
        #expect(catalog.gestures.count == 100)
        #expect(catalog.gameQuestions.count == 60)

        let ids = catalog.questions.map(\.id) + catalog.dates.map(\.id) + catalog.gestures.map(\.id) + catalog.gameQuestions.map(\.id)
        #expect(Set(ids).count == 625)
        #expect(catalog.questionsVersion == "1.0.0")
    }

    @Test func questionsAlternateFiveThemesEvenly() throws {
        let catalog = try MomentsCatalog.load()
        let counts = Dictionary(grouping: catalog.questions, by: \.category).mapValues(\.count)
        #expect(counts == Dictionary(uniqueKeysWithValues: QuestionCategory.allCases.map { ($0, 73) }))
        for (index, question) in catalog.questions.enumerated() {
            #expect(question.category == QuestionCategory.allCases[index % 5], "\(question.id)")
        }
    }

    @Test func datesAndGameItemsAreComplete() throws {
        let catalog = try MomentsCatalog.load()
        let groups = Dictionary(grouping: catalog.dates, by: \.editorialGroup).mapValues(\.count)
        #expect(groups == ["gratuitas": 25, "economicas": 25, "em_casa": 25, "passeios": 25])
        for date in catalog.dates {
            #expect(!date.materials.isEmpty && date.durationMinutes > 0, "\(date.id)")
        }
        for question in catalog.gameQuestions {
            #expect(question.options.count == 4)
            #expect(Set(question.options.map(\.id)).count == 4)
            #expect(Set(question.options.map { $0.text.lowercased() }).count == 4)
        }
        // Remote ideas are never "out of home" activities.
        #expect(catalog.dates.filter { $0.remoteFriendly && $0.location == .fora }.isEmpty)
    }

    @Test func validationRejectsDuplicateIDsAndBadOptions() throws {
        let catalog = try MomentsCatalog.load()
        let duplicated = MomentsCatalog(
            questions: catalog.questions + [catalog.questions[0]],
            dates: catalog.dates, gestures: catalog.gestures, gameQuestions: catalog.gameQuestions,
            questionsVersion: "x", datesVersion: "x", gesturesVersion: "x", gameVersion: "x"
        )
        #expect(throws: MomentsCatalog.CatalogError.duplicateID(catalog.questions[0].id)) { try duplicated.validate() }

        let first = catalog.gameQuestions[0]
        let broken = CatalogGameQuestion(id: first.id, text: first.text, options: Array(first.options.prefix(3)), intensity: first.intensity)
        let badGame = MomentsCatalog(
            questions: catalog.questions, dates: catalog.dates, gestures: catalog.gestures,
            gameQuestions: [broken] + catalog.gameQuestions.dropFirst(),
            questionsVersion: "x", datesVersion: "x", gesturesVersion: "x", gameVersion: "x"
        )
        #expect(throws: MomentsCatalog.CatalogError.invalidItem(first.id)) { try badGame.validate() }
    }

    /// A store written with model v1 (the version on the iPhones) opens with v2 and keeps
    /// every record. Uses a temporary copy, never a real store.
    @Test func modelV1StoreMigratesWithItsData() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "MigrationTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let momd = try #require(Bundle(for: PersistenceController.self).url(forResource: "AppCasal", withExtension: "momd"))
        let v1 = try #require(NSManagedObjectModel(contentsOf: momd.appending(path: "AppCasal.mom")))
        #expect(v1.entitiesByName["DailyQuestion"] == nil)

        let spaceID = UUID()
        do {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1)
            let options: [String: Any] = [NSPersistentHistoryTrackingKey: true]
            let store = try coordinator.addPersistentStore(type: .sqlite, at: directory.appending(path: "Private.sqlite"), options: options)
            let context = NSManagedObjectContext(.mainQueue)
            context.persistentStoreCoordinator = coordinator
            let space = NSEntityDescription.insertNewObject(forEntityName: "CoupleSpace", into: context)
            space.setValue(spaceID, forKey: "id")
            space.setValue(Date(timeIntervalSince1970: 1_700_000_000), forKey: "createdAt")
            let memory = NSEntityDescription.insertNewObject(forEntityName: "Memory", into: context)
            memory.setValue(UUID(), forKey: "id")
            memory.setValue("Primeiro encontro", forKey: "title")
            memory.setValue(space, forKey: "space")
            let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context)
            note.setValue(UUID(), forKey: "id")
            note.setValue("Bom dia", forKey: "text")
            note.setValue(space, forKey: "space")
            let place = NSEntityDescription.insertNewObject(forEntityName: "Place", into: context)
            place.setValue(UUID(), forKey: "id")
            place.setValue("Mirante", forKey: "name")
            place.setValue("wishlist", forKey: "status")
            place.setValue(space, forKey: "space")
            try context.save()
            try coordinator.remove(store)
        }

        let persistence = PersistenceController(mode: .local(directory: directory))
        #expect(persistence.loadError == nil)
        let spaces = try persistence.viewContext.fetch(CoupleSpace.fetchRequest())
        let space = try #require(spaces.first)
        #expect(spaces.count == 1 && space.id == spaceID)
        #expect(space.memories?.first?.title == "Primeiro encontro")
        #expect(space.notes?.first?.text == "Bom dia")
        #expect(space.places?.first?.name == "Mirante")
        #expect(space.momentsTimeZone == nil)

        // The migrated space takes the new records.
        let catalog = try MomentsCatalog.load()
        let prepared = try MomentsRepository(persistence: persistence).prepareDays(
            in: space, questions: catalog.questions, catalogVersion: catalog.questionsVersion, by: "_owner"
        )
        #expect(prepared == DailyQuestionPlanner.daysAhead)
    }
}
