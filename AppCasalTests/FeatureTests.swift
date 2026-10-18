//
//  FeatureTests.swift
//  AppCasalTests
//

import CoreData
import Foundation
import Testing
@testable import AppCasal

struct FeatureTests {
    private let owner = "_owner"
    private let partner = "_partner"

    private func makeSpace(_ persistence: PersistenceController) throws -> CoupleSpace {
        try SpaceRepository(persistence: persistence).createSpace(ownerName: "Ana", userRecordName: owner)
    }

    // MARK: Places

    @Test func placeLifecycle() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let places = PlaceRepository(persistence: persistence)

        let place = try places.create(
            PlaceDraft(name: " Café do Centro ", address: "Centro", latitude: -27.59, longitude: -48.54, category: .restaurant),
            in: space, by: owner
        )
        #expect(place.name == "Café do Centro")
        #expect(place.placeStatus == .wishlist)
        #expect(place.visitedAt == nil)
        #expect(place.objectID.persistentStore == persistence.privateStore)

        let memoryID = UUID()
        let visitDate = Date(timeIntervalSince1970: 1_790_000_000)
        try places.markVisited(place, memoryID: memoryID, on: visitDate, by: partner)
        #expect(place.placeStatus == .visited)
        #expect(place.visitedAt == visitDate)
        #expect(place.memoryID == memoryID)
        #expect(place.modifiedBy == partner)

        try places.update(place, category: .date, status: .wishlist, note: "  ", by: owner)
        #expect(place.placeStatus == .wishlist && place.visitedAt == nil)
        #expect(place.note == nil)

        try places.softDelete(place, by: owner)
        #expect(place.deletedAt != nil && !place.isDeleted)
        #expect(places.place(withID: try #require(place.id), in: space) == nil)
        try places.restore(place, by: partner)
        #expect(place.deletedAt == nil)
    }

    @Test func memoryKeepsPlaceLink() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let placeID = UUID()
        var draft = MemoryDraft(title: "Pôr do sol")
        draft.place = PlaceLink(placeID: placeID, name: "Praia", latitude: -27.6, longitude: -48.4)
        let memory = try MemoryRepository(persistence: persistence).create(draft, photos: [], in: space, by: owner)
        #expect(memory.placeID == placeID)
        #expect(memory.locationName == "Praia")
        #expect(memory.latitude?.doubleValue == -27.6)
        #expect(memory.hasLocation)
    }

    // MARK: Goals

    @Test func goalStepsDriveProgress() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let goals = GoalRepository(persistence: persistence)
        var draft = GoalDraft(title: "Viagem", category: .trip)
        draft.steps = ["Destino", "Passagens", " ", "Hotel", "Roteiro"].map { .init(title: $0) }

        let goal = try goals.create(draft, in: space, by: owner)
        #expect(goal.visibleSteps.map(\.title) == ["Destino", "Passagens", "Hotel", "Roteiro"], "blank steps are dropped")
        #expect(goal.progress == 0)
        #expect(goal.visibleSteps.allSatisfy { $0.objectID.persistentStore == persistence.privateStore })

        try goals.toggle(goal.visibleSteps[0], by: owner)
        try goals.toggle(goal.visibleSteps[1], by: partner)
        #expect(goal.completedStepCount == 2)
        #expect(goal.progress == 0.5)
        #expect(goal.visibleSteps[1].doneBy == partner)
        try goals.toggle(goal.visibleSteps[1], by: owner)
        #expect(goal.completedStepCount == 1)
    }

    @Test func goalEditRenamesRemovesAndAddsSteps() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let goals = GoalRepository(persistence: persistence)
        var draft = GoalDraft(title: "Casa")
        draft.steps = ["A", "B", "C"].map { .init(title: $0) }
        let goal = try goals.create(draft, in: space, by: owner)
        let removed = goal.visibleSteps[1]

        var edit = goals.draft(for: goal)
        edit.steps.remove(at: 1)
        edit.steps[0].title = "A2"
        edit.steps.append(.init(title: "D"))
        edit.steps.swapAt(0, 1)
        edit.dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        try goals.update(goal, with: edit, by: partner)

        #expect(goal.visibleSteps.map(\.title) == ["C", "A2", "D"])
        #expect(removed.deletedAt != nil && removed.deletedBy == partner && !removed.isDeleted, "removal is logical")
        #expect(goal.dueDate == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(goal.modifiedBy == partner)
    }

    @Test func goalCompletionHistoryAndValidation() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let goals = GoalRepository(persistence: persistence)
        #expect(throws: GoalRepository.GoalError.self) {
            try goals.create(GoalDraft(title: "  "), in: space, by: owner)
        }
        let goal = try goals.create(GoalDraft(title: "Plantinha"), in: space, by: owner)
        #expect(goal.progress == 0)
        try goals.complete(goal, by: partner)
        #expect(goal.isCompleted && goal.completedBy == partner && goal.progress == 1)
        try goals.reopen(goal, by: owner)
        #expect(!goal.isCompleted && goal.completedBy == nil)
        try goals.softDelete(goal, by: owner)
        #expect(goal.deletedAt != nil)
        try goals.restore(goal, by: partner)
        #expect(goal.deletedAt == nil)
    }

    // MARK: Notes and favorites

    @Test func notesValidateTextAndRecipient() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let notes = NoteRepository(persistence: persistence)
        #expect(throws: NoteRepository.NoteError.self) {
            try notes.create(text: "   ", in: space, by: owner)
        }
        let note = try notes.create(text: " Oi ", to: partner, in: space, by: owner)
        #expect(note.text == "Oi")
        #expect(note.recipientID == partner)
    }

    @Test func favoritesArePersonalAndPrivate() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let note = try NoteRepository(persistence: persistence).create(text: "Oi", in: space, by: partner)
        let favorites = FavoriteRepository(persistence: persistence)
        let noteID = try #require(note.id)

        try favorites.toggle(noteID: noteID, for: owner)
        #expect(favorites.favoriteNoteIDs(for: owner) == [noteID])
        #expect(favorites.favoriteNoteIDs(for: partner).isEmpty, "partner does not see my favorites")

        let request = NoteFavorite.fetchRequest()
        let stored = try persistence.viewContext.fetch(request)
        #expect(stored.count == 1)
        #expect(stored.first?.objectID.persistentStore == persistence.privateStore)

        try favorites.toggle(noteID: noteID, for: owner)
        #expect(favorites.favoriteNoteIDs(for: owner).isEmpty)
    }

    // MARK: Space

    @Test func spacePhotosAndArchive() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let spaces = SpaceRepository(persistence: persistence)
        let space = try spaces.createSpace(ownerName: "Ana", userRecordName: owner)
        let member = try #require(spaces.member(for: owner, in: space))

        try spaces.setCoverPhoto(Data([1, 2, 3]), in: space)
        try spaces.setAvatar(Data([4, 5]), for: member)
        #expect(space.coverPhotoData == Data([1, 2, 3]))
        #expect(member.avatarData == Data([4, 5]))

        try spaces.archive(space)
        #expect(spaces.activeSpace() == nil, "archived space is not active; a new one can be created")
        #expect(!space.isDeleted, "archiving keeps the data")
        let fresh = try spaces.createSpace(ownerName: "Ana", userRecordName: owner)
        #expect(spaces.activeSpace() == fresh)
        #expect(fresh.notes?.isEmpty ?? true, "the new space starts empty")
    }
}
