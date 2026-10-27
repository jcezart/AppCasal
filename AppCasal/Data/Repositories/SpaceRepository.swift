//
//  SpaceRepository.swift
//  AppCasal
//

import CoreData

/// Creates and finds the couple space and its members.
final class SpaceRepository {
    enum SpaceError: LocalizedError {
        case storeUnavailable

        var errorDescription: String? {
            switch self {
            case .storeUnavailable:
                String(localized: "O armazenamento local não está disponível.")
            }
        }
    }

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    /// The active space. A user has at most one; owned spaces win over shared ones.
    func activeSpace() -> CoupleSpace? {
        let request = CoupleSpace.fetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CoupleSpace.createdAt, ascending: true)]
        let spaces = (try? context.fetch(request)) ?? []
        return spaces.first { !persistence.isInSharedStore($0) } ?? spaces.first
    }

    func role(in space: CoupleSpace) -> Member.Role {
        persistence.isInSharedStore(space) ? .participant : .owner
    }

    func createSpace(ownerName: String, userRecordName: String, now: Date = .now) throws -> CoupleSpace {
        guard let store = persistence.privateStore else { throw SpaceError.storeUnavailable }

        let space = CoupleSpace(context: context)
        context.assign(space, to: store)
        space.id = UUID()
        space.createdAt = now
        space.modifiedAt = now
        space.createdBy = userRecordName

        insertMember(named: ownerName, userRecordName: userRecordName, role: .owner, in: space, now: now)
        try persistence.save()
        return space
    }

    func member(for userRecordName: String, in space: CoupleSpace) -> Member? {
        space.members?.first { $0.userRecordName == userRecordName }
    }

    /// Creates the current user's member record in `space` if it does not exist yet.
    /// Called by the participant once the shared space has been imported.
    @discardableResult
    func ensureMember(named name: String, userRecordName: String, in space: CoupleSpace, now: Date = .now) throws -> Member {
        if let existing = member(for: userRecordName, in: space) {
            return existing
        }
        let member = insertMember(named: name, userRecordName: userRecordName, role: role(in: space), in: space, now: now)
        try persistence.save()
        return member
    }

    /// The other partner, if they already joined.
    func partner(of userRecordName: String, in space: CoupleSpace) -> Member? {
        space.members?.first { $0.userRecordName != userRecordName }
    }

    func updateDisplayName(_ member: Member, to name: String, now: Date = .now) throws {
        member.displayName = name
        member.modifiedAt = now
        try persistence.save()
    }

    func setCoverPhoto(_ data: Data?, in space: CoupleSpace, now: Date = .now) throws {
        space.coverPhotoData = data
        space.modifiedAt = now
        try persistence.save()
    }

    func setAvatar(_ data: Data?, for member: Member, now: Date = .now) throws {
        member.avatarData = data
        member.modifiedAt = now
        try persistence.save()
    }

    /// Owner only, after the partnership ended: archives the space (logical deletion, data
    /// kept) so a new relationship starts in a new, empty space.
    func archive(_ space: CoupleSpace, now: Date = .now) throws {
        space.deletedAt = now
        space.modifiedAt = now
        try persistence.save()
    }

    func setRelationshipStart(_ date: Date?, in space: CoupleSpace, now: Date = .now) throws {
        space.relationshipStart = date
        space.modifiedAt = now
        try persistence.save()
    }

    /// A subscriber's device records how long the couple has access. Only moves forward,
    /// so an older device or an earlier transaction never shortens it.
    func recordAccess(until expiration: Date, in space: CoupleSpace, now: Date = .now) throws {
        if let current = space.accessExpiresAt, current >= expiration { return }
        space.accessExpiresAt = expiration
        space.modifiedAt = now
        try persistence.save()
    }

    @discardableResult
    private func insertMember(
        named name: String,
        userRecordName: String,
        role: Member.Role,
        in space: CoupleSpace,
        now: Date
    ) -> Member {
        let member = Member(context: context)
        // Related objects must live in the same store as the space.
        if let store = space.objectID.persistentStore {
            context.assign(member, to: store)
        }
        member.id = UUID()
        member.displayName = name
        member.userRecordName = userRecordName
        member.role = role.rawValue
        member.createdAt = now
        member.modifiedAt = now
        member.space = space
        return member
    }
}
