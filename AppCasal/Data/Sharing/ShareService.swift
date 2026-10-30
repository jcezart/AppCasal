//
//  ShareService.swift
//  AppCasal
//

import CloudKit
import CoreData
import LinkPresentation
import Observation
import UIKit

/// Creates, presents and accepts the couple space share.
///
/// The space is shared privately (no public link) with read-write permission,
/// and never with more than one partner (see `CoupleLimit`).
@Observable
final class ShareService {
    enum AcceptanceState: Equatable {
        case idle
        case accepting
        case accepted
        case rejected(String)
        case failed(String)
    }

    enum ShareError: LocalizedError {
        case storeUnavailable
        case partnershipEnded

        var errorDescription: String? {
            switch self {
            case .storeUnavailable:
                String(localized: "O armazenamento local não está disponível.")
            case .partnershipEnded:
                String(localized: "O compartilhamento deste espaço foi encerrado. Um novo relacionamento começa em um novo espaço.")
            }
        }
    }

    private(set) var acceptance: AcceptanceState = .idle
    private(set) var lastError: String?
    /// Incremented when the share changes outside the app's own calls (sharing UI).
    private(set) var shareRevision = 0

    private let persistence: PersistenceController
    private let spaces: SpaceRepository
    @ObservationIgnored private lazy var sharingDelegate = SharingControllerDelegate(service: self)
    /// Space whose share is shown in the sharing UI.
    @ObservationIgnored private var presentedSpace: CoupleSpace?

    init(persistence: PersistenceController, spaces: SpaceRepository) {
        self.persistence = persistence
        self.spaces = spaces
    }

    func existingShare(for space: CoupleSpace) -> CKShare? {
        let shares = try? persistence.container.fetchShares(matching: [space.objectID])
        return shares?[space.objectID]
    }

    func createShare(for space: CoupleSpace) async throws -> CKShare {
        guard space.sharingEndedAt == nil else { throw ShareError.partnershipEnded }
        guard let store = persistence.privateStore else { throw ShareError.storeUnavailable }
        let (_, share, _) = try await persistence.container.share([space], to: nil)
        share[CKShare.SystemFieldKey.title] = String(localized: "Nosso espaço")
        share[CKShare.SystemFieldKey.thumbnailImageData] = ShareThumbnail.data(for: space)
        share.publicPermission = .none
        let saved = try await persistence.container.persistUpdatedShare(share, in: store)
        shareRevision += 1
        return saved
    }

    /// Invitations reach only the people it is sent to, with read-write access: the
    /// same rules as `UICloudSharingController`.
    static let invitationOptions = CKAllowedSharingOptions(
        allowedParticipantPermissionOptions: .readWrite,
        allowedParticipantAccessOptions: .specifiedRecipientsOnly
    )

    /// The space's saved share, created when it does not exist yet.
    func ensureShare(for space: CoupleSpace) async throws -> CKShare {
        if let existing = existingShare(for: space) {
            return existing
        }
        return try await createShare(for: space)
    }

    /// Saves the share first when needed, then opens the share sheet with it. With the
    /// share already saved, the app picked in the sheet (WhatsApp, Mensagens…) opens on
    /// the first tap; letting the sheet prepare the share sent the person back to it.
    func presentInvitation(for space: CoupleSpace) async throws {
        let share = try await ensureShare(for: space)
        let provider = NSItemProvider()
        provider.registerCKShare(share, container: persistence.cloudKitContainer, allowedSharingOptions: Self.invitationOptions)
        let configuration = UIActivityItemsConfiguration(itemProviders: [provider])
        let metadata = LPLinkMetadata()
        metadata.title = String(localized: "Nosso espaço")
        metadata.imageProvider = NSItemProvider(object: ShareThumbnail.image(for: space))
        configuration.metadataProvider = { key in
            switch key {
            case .title: metadata.title
            case .linkPresentationMetadata: metadata
            default: nil
            }
        }
        Self.topViewController()?.present(UIActivityViewController(activityItemsConfiguration: configuration), animated: true)
    }

    /// Presents the system sharing UI, restricted to private, read-write invitations.
    func presentSharingController(for share: CKShare, of space: CoupleSpace) {
        presentedSpace = space
        let controller = UICloudSharingController(share: share, container: persistence.cloudKitContainer)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = sharingDelegate
        Self.topViewController()?.present(controller, animated: true)
    }

    enum AcceptDecision: Equatable {
        case accept
        /// The same invitation opened again.
        case alreadyIn
        case ownsASpace
        /// Another couple's invitation: two shared spaces would mix both couples in the
        /// shared database (and in its alerts).
        case inAnotherSpace
    }

    /// One space per person: an owner never joins another space, and a participant joins
    /// no second one.
    nonisolated static func decision(currentRole: Member.Role?, currentZone: CKRecordZone.ID?, invitedZone: CKRecordZone.ID) -> AcceptDecision {
        switch currentRole {
        case nil: .accept
        case .owner: .ownsASpace
        case .participant: currentZone == invitedZone ? .alreadyIn : .inAnotherSpace
        }
    }

    /// Clears a rejection or failure once the person has seen it.
    func dismissAcceptanceMessage() {
        switch acceptance {
        case .rejected, .failed: acceptance = .idle
        default: break
        }
    }

    /// The accepted space is on this iPhone (or the person gave up waiting): back to idle,
    /// so the free pass of `AccessRules.isJoiningSpace` ends with the joining itself.
    func finishAcceptance() {
        guard acceptance == .accepted else { return }
        acceptance = .idle
    }

    func accept(_ metadata: CKShare.Metadata) async {
        guard CoupleLimit.isValidCouple(CoupleLimit.summaries(of: metadata.share)) else {
            acceptance = .rejected(String(localized: "Este convite inclui mais de uma pessoa além do dono. Um espaço é só para o casal."))
            return
        }
        let current = spaces.activeSpace()
        switch Self.decision(
            currentRole: current.map(spaces.role(in:)),
            currentZone: current.flatMap(existingShare(for:))?.recordID.zoneID,
            invitedZone: metadata.share.recordID.zoneID
        ) {
        case .accept:
            break
        case .alreadyIn:
            acceptance = .accepted
            return
        case .ownsASpace:
            acceptance = .rejected(String(localized: "Você já tem um espaço próprio. Por enquanto, cada pessoa participa de um único espaço."))
            return
        case .inAnotherSpace:
            acceptance = .rejected(String(localized: "Você já participa de um espaço. Para entrar em outro, saia do atual em Nosso espaço."))
            return
        }
        guard let store = persistence.sharedStore else {
            acceptance = .failed(ShareError.storeUnavailable.localizedDescription)
            return
        }
        acceptance = .accepting
        do {
            _ = try await persistence.container.acceptShareInvitations(from: [metadata], into: store)
            acceptance = .accepted
        } catch {
            acceptance = .failed(error.localizedDescription)
        }
    }

    /// Participant leaves the couple space. Purging the shared zone from the shared database
    /// removes this user from the share and deletes the local copy; the owner's data is
    /// untouched. (Behavior to validate with two accounts: S8.)
    func leave(_ space: CoupleSpace) async throws {
        guard let store = persistence.sharedStore, persistence.isInSharedStore(space),
              let share = existingShare(for: space) else { throw ShareError.storeUnavailable }
        _ = try await persistence.container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store)
        acceptance = .idle
        shareRevision += 1
    }

    /// Owner permanently deletes the space and everything in it, for both partners.
    /// Shared: purges the share zone (data and share). Not shared: deletes the objects,
    /// and mirroring deletes the records.
    func deletePermanently(_ space: CoupleSpace) async throws {
        guard !persistence.isInSharedStore(space) else { throw ShareError.storeUnavailable }
        if let share = existingShare(for: space), let store = persistence.privateStore {
            _ = try await persistence.container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store)
        } else {
            persistence.viewContext.delete(space)
            try persistence.save()
        }
        shareRevision += 1
    }

    /// Owner starts over: the space is archived (data kept) and its share, if still there,
    /// is deleted first. Otherwise an old invitation link could still bring someone into
    /// the archived space, which their iPhone would never show (stuck on "Convite aceito").
    /// Needs the network when a share exists: nothing is archived if deleting it fails.
    func archive(_ space: CoupleSpace) async throws {
        guard !persistence.isInSharedStore(space) else { throw ShareError.storeUnavailable }
        if let share = existingShare(for: space) {
            do {
                try await persistence.cloudKitContainer.privateCloudDatabase.deleteRecord(withID: share.recordID)
            } catch let error as CKError where error.code == .unknownItem {
                // Already deleted elsewhere.
            }
        }
        if space.sharingEndedAt == nil {
            space.sharingEndedAt = .now
        }
        try spaces.archive(space)
        shareRevision += 1
    }

    fileprivate func sharingControllerDidSave(_ share: CKShare?) {
        guard let share, let store = persistence.privateStore else { return }
        Task {
            do {
                _ = try await persistence.container.persistUpdatedShare(share, in: store)
            } catch {
                lastError = error.localizedDescription
            }
            shareRevision += 1
        }
    }

    fileprivate func sharingControllerDidStop() {
        // Stopping sharing keeps the owner's data; nothing is purged here.
        // The space is marked so it is never shared again with someone else.
        if let space = presentedSpace {
            space.sharingEndedAt = .now
            space.modifiedAt = .now
            do {
                try persistence.save()
            } catch {
                lastError = error.localizedDescription
            }
        }
        shareRevision += 1
    }

    fileprivate var presentedThumbnail: Data? {
        presentedSpace.flatMap(ShareThumbnail.data(for:))
    }

    fileprivate func sharingControllerFailed(_ error: Error) {
        lastError = error.localizedDescription
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

private final class SharingControllerDelegate: NSObject, UICloudSharingControllerDelegate {
    private weak var service: ShareService?

    init(service: ShareService) {
        self.service = service
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        String(localized: "Nosso espaço")
    }

    func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
        service?.presentedThumbnail
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        service?.sharingControllerFailed(error)
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        service?.sharingControllerDidSave(csc.share)
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        service?.sharingControllerDidStop()
    }
}
