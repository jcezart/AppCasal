//
//  Avatars.swift
//  AppCasal
//

import SwiftUI
import UIKit

/// Circular avatar: photo when available, otherwise the initial of the name.
struct AvatarView: View {
    let name: String
    var imageData: Data?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Palette.surfaceMuted)
            DecodedImage(data: imageData) {
                Text(initial)
                    .font(.system(size: size * 0.42, design: .serif))
                    .foregroundStyle(Palette.accentText)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(Circle().strokeBorder(Palette.surface, lineWidth: 2))
        .accessibilityHidden(true)
    }

    private var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }
}

/// Both partners side by side with a heart, as in "Nosso espaço".
struct CoupleAvatars: View {
    let firstName: String
    let secondName: String?
    var firstPhoto: Data?
    var secondPhoto: Data?

    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 88

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            person(firstName, photo: firstPhoto)
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .padding(.top, size / 2 - 10)
                .accessibilityHidden(true)
            if let secondName {
                person(secondName, photo: secondPhoto)
            } else {
                VStack(spacing: Spacing.xs) {
                    Circle()
                        .strokeBorder(Palette.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .frame(width: size, height: size)
                        .overlay(Image(systemName: "person.badge.plus").foregroundStyle(Palette.textSecondary))
                    Text("Aguardando")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Parceiro ou parceira ainda não entrou"))
            }
        }
    }

    private func person(_ name: String, photo: Data?) -> some View {
        VStack(spacing: Spacing.xs) {
            AvatarView(name: name, imageData: photo, size: size)
            Text(name)
                .font(.cardTitle)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        AvatarView(name: "Ana")
        CoupleAvatars(firstName: "Ana", secondName: "Lucas")
        CoupleAvatars(firstName: "Ana", secondName: nil)
    }
    .padding()
    .background(Palette.canvas)
}
