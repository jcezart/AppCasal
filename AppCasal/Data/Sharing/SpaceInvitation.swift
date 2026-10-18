//
//  SpaceInvitation.swift
//  AppCasal
//

import CloudKit
import CoreTransferable
import SwiftUI
import UIKit

/// The couple space as a `ShareLink` item. The system share sheet sends the CloudKit
/// invitation through any app (WhatsApp, Mensagens…), restricted to invited people
/// with read-write access, the same rules as `UICloudSharingController`.
nonisolated struct SpaceInvitation: Transferable {
    let container: CKContainer
    /// Saved share, when the space was already shared. The sheet then only sends its link.
    let existing: CKShare?
    /// Creates the share when the person picks where to send it.
    let prepare: @Sendable () async throws -> CKShare

    static let sharingOptions = CKAllowedSharingOptions(
        allowedParticipantPermissionOptions: .readWrite,
        allowedParticipantAccessOptions: .specifiedRecipientsOnly
    )

    static var transferRepresentation: some TransferRepresentation {
        CKShareTransferRepresentation { invitation in
            if let share = invitation.existing {
                return .existing(share, container: invitation.container, allowedSharingOptions: sharingOptions)
            }
            return .prepareShare(container: invitation.container, allowedSharingOptions: sharingOptions, preparationHandler: invitation.prepare)
        }
    }
}

/// Square picture shown for the invitation: the couple photo, or the app logo on the
/// launch background. Replaces the generic document icon of the sharing screens.
enum ShareThumbnail {
    private static let side: CGFloat = 256

    static func image(for space: CoupleSpace) -> UIImage {
        let photo = space.coverPhotoData.flatMap(UIImage.init(data:))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let bounds = CGRect(x: 0, y: 0, width: side, height: side)
            if let photo {
                // Aspect fill, centered.
                let scale = max(side / photo.size.width, side / photo.size.height)
                let size = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
                photo.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
            } else {
                UIColor(named: "LaunchBackground")?.setFill()
                UIRectFill(bounds)
                if let logo = UIImage(named: "LaunchLogo") {
                    let logoSide = side * 0.6
                    logo.draw(in: CGRect(x: (side - logoSide) / 2, y: (side - logoSide) / 2, width: logoSide, height: logoSide))
                }
            }
        }
    }

    static func data(for space: CoupleSpace) -> Data? {
        image(for: space).jpegData(compressionQuality: 0.8)
    }
}
