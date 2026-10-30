//
//  PillSegmentedControl.swift
//  AppCasal
//

import SwiftUI

/// Pill-shaped segmented control with a terracotta selection, as in the reference.
/// Solid (not glass): it sits on the page, above stable content.
struct PillSegmentedControl<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: LocalizedStringKey
        var id: Value { value }
    }

    @Binding var selection: Value
    let options: [Option]

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the segments stack so labels are never truncated.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.xxs) { segments }
                .padding(Spacing.xxs)
                .background(Palette.surfaceMuted, in: .rect(cornerRadius: Radius.card, style: .continuous))
        } else {
            HStack(spacing: Spacing.xxs) { segments }
                .padding(Spacing.xxs)
                .background(Palette.surfaceMuted, in: .capsule)
        }
    }

    private var segments: some View {
        ForEach(options) { option in
            segment(option)
        }
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option.value == selection
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                selection = option.value
            }
        } label: {
            Text(option.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.8)
                // 44 pt: Apple's minimum touch target.
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, Spacing.xs)
                .foregroundStyle(isSelected ? Palette.onAccent : Palette.textSecondary)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Palette.accent)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection = 0
    PillSegmentedControl(selection: $selection, options: [
        .init(value: 0, title: "Recebidos"),
        .init(value: 1, title: "Enviados"),
        .init(value: 2, title: "Favoritos"),
    ])
    .padding()
    .background(Palette.canvas)
}
