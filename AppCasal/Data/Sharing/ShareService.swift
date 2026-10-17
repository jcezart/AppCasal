//
//  ShareService.swift
//  AppCasal
//

import CloudKit
import CoreData
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
        share.publicPermission = .none
        return try await persistence.container.persistUpdatedShare(share, in: store)
    }

    /// Presents the system sharing UI, restricted to private, read-write invitations.
    func presentSharingController(for share: CKShare, of space: CoupleSpace) {
        presentedSpace = space
        let controller = UICloudSharingController(share: share, container: persistence.cloudKitContainer)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = sharingDelegate
        Self.topViewController()?.present(controller, animated: true)
    }

    func accept(_ metadata: CKShare.Metadata) async {
        guard CoupleLimit.isValidCouple(CoupleLimit.summaries(of: metadata.share)) else {
            acceptance = .rejected(String(localized: "Este convite inclui mais de uma pessoa além do dono. Um espaço é só para o casal."))
            return
        }
        if let current = spaces.activeSpace(), spaces.role(in: current) == .owner {
            acceptance = .rejected(String(localized: "Você já tem um espaço próprio. Por enquanto, cada pessoa participa de um único espaço."))
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
