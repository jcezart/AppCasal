//
//  SpaceInvitation.swift
//  AppCasal
//

import UIKit

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
