//
//  MemoryCards.swift
//  AppCasal
//

import SwiftUI

/// Memory in the timeline: date, cover photo, serif title, description and category.
struct MemoryCard: View {
    @ObservedObject var memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(memory.date ?? .now, format: .dateTime.day().month(.abbreviated).year())
                .font(.metadata)
                .foregroundStyle(Palette.textSecondary)
            if let cover = memory.visiblePhotos.first {
                PhotoView(photo: cover)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: Radius.photo, style: .continuous))
                    .overlay(alignment: .bottomTrailing) { photoCount }
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(memory.title ?? "")
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                if let details = memory.details {
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                }
            }
            HStack(spacing: Spacing.xs) {
                if let location = memory.locationName {
                    TagChip(title: location, systemImage: "mappin")
                }
                TagChip(title: memory.memoryCategory.title, systemImage: memory.memoryCategory.systemImage)
            }
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var photoCount: some View {
        let count = memory.visiblePhotos.count
        if count > 1 {
            Label("\(count)", systemImage: "photo.on.rectangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(Palette.surface.opacity(0.9), in: .capsule)
                .padding(Spacing.xs)
                .accessibilityLabel(Text("\(count) fotos"))
        }
    }
}

/// Compact memory row used on Início ("Última memória").
struct MemoryRow: View {
    @ObservedObject var memory: Memory

    @ScaledMetric(relativeTo: .body) private var thumbnailSize: CGFloat = 64

    var body: some View {
        AdaptiveStack {
            if let cover = memory.visiblePhotos.first {
                PhotoView(photo: cover)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(.rect(cornerRadius: Radius.photo, style: .continuous))
            } else {
                Image(systemName: memory.memoryCategory.systemImage)
                    .font(.title3)
                    .foregroundStyle(Palette.accentText)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .background(Palette.surfaceMuted, in: .rect(cornerRadius: Radius.photo, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(memory.title ?? "")
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text(memory.date ?? .now, format: .dateTime.day().month(.abbreviated).year())
                    .font(.metadata)
                    .foregroundStyle(Palette.textSecondary)
                TagChip(title: memory.memoryCategory.title)
            }
            Spacer(minLength: 0)
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}
