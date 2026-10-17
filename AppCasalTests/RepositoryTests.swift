//
//  RepositoryTests.swift
//  AppCasalTests
//

import CoreData
import Foundation
import Testing
@testable import AppCasal

struct RepositoryTests {
    private let owner = "_owner-record-name"

    @Test func createSpaceAddsOwnerInPrivateStore() throws {
        let persistence = PersistenceController(mode: .inMemory)
        #expect(persistence.loadError == nil)
        let spaces = SpaceRepository(persistence: persistence)

        let space = try spaces.createSpace(ownerName: "Ana", userRecordName: owner)

        #expect(spaces.role(in: space) == .owner)
        #expect(space.objectID.persistentStore == persistence.privateStore)
        let member = try #require(spaces.member(for: owner, in: space))
        #expect(member.role == Member.Role.owner.rawValue)
        #expect(member.objectID.persistentStore == persistence.privateStore)
        #expect(spaces.activeSpace() == space)
    }

    @Test func ensureMemberIsIdempotent() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let spaces = SpaceRepository(persistence: persistence)
        let space = try spaces.createSpace(ownerName: "Ana", userRecordName: owner)

        let first = try spaces.ensureMember(named: "Ana", userRecordName: owner, in: space)
        let second = try spaces.ensureMember(named: "Ana", userRecordName: owner, in: space)

        #expect(first == second)
        #expect(space.members?.count == 1)
    }

    @Test func noteLifecycleUsesLogicalDeletion() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try SpaceRepository(persistence: persistence).createSpace(ownerName: "Ana", userRecordName: owner)
        let notes = NoteRepository(persistence: persistence)
        let partner = "_partner-record-name"

        let note = try notes.create(text: "Oi", in: space, by: owner)
        #expect(note.objectID.persistentStore == persistence.privateStore)

        try notes.update(note, text: "Oi, amor", by: partner)
        #expect(note.text == "Oi, amor")
        #expect(note.modifiedBy == partner)
        #expect(note.authorID == owner)

        try notes.softDelete(note, by: partner)
        #expect(note.deletedAt != nil)
        #expect(note.deletedBy == partner)
        #expect(!note.isDeleted, "logical deletion keeps the object")

        try notes.restore(note, by: owner)
        #expect(note.deletedAt == nil)
        #expect(note.deletedBy == nil)
    }

    /// Simulates closing and reopening the app: data must survive a new stack on the same files.
    @Test func dataSurvivesReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            let persistence = PersistenceController(mode: .local(directory: directory))
            #expect(persistence.loadError == nil)
            let space = try SpaceRepository(persistence: persistence).createSpace(ownerName: "Ana", userRecordName: owner)
            let note = try NoteRepository(persistence: persistence).create(text: "Primeiro", in: space, by: owner)
            try NoteRepository(persistence: persistence).update(note, text: "Editado", by: owner)
            for store in persistence.container.persistentStoreCoordinator.persistentStores {
                try persistence.container.persistentStoreCoordinator.remove(store)
            }
        }

        let reopened = PersistenceController(mode: .local(directory: directory))
        #expect(reopened.loadError == nil)
        let space = try #require(SpaceRepository(persistence: reopened).activeSpace())
        let notes = try #require(space.notes)
        #expect(notes.count == 1)
        #expect(notes.first?.text == "Editado")
        #expect(space.members?.first?.displayName == "Ana")
    }
}
