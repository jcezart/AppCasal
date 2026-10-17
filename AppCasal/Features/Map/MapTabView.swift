//
//  MapTabView.swift
//  AppCasal
//

import MapKit
import SwiftUI

/// Mapa: places will be added in the map increment. Floating controls use Liquid Glass
/// because they sit over changing map content.
struct MapTabView: View {
    enum Filter: Hashable, CaseIterable {
        case all
        case visited
        case wishlist

        var title: LocalizedStringKey {
            switch self {
            case .all: "Todos"
            case .visited: "Visitados"
            case .wishlist: "Queremos ir"
            }
        }
    }

    @State private var filter = Filter.all

    var body: some View {
        Map()
            .safeAreaInset(edge: .top) {
                filterBar
            }
            .safeAreaInset(edge: .bottom) {
                InfoCard(
                    systemImage: "mappin.and.ellipse",
                    title: "Nenhum lugar salvo ainda",
                    message: "Os lugares que vocês visitaram e os que querem conhecer vão aparecer no mapa."
                )
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.xs)
            }
            .toolbar(.hidden, for: .navigationBar)
    }

    private var filterBar: some View {
        GlassEffectContainer(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                ForEach(Filter.allCases, id: \.self) { option in
                    filterButton(option)
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.xs)
    }

    private func filterButton(_ option: Filter) -> some View {
        let isSelected = option == filter
        return Button {
            filter = option
        } label: {
            Text(option.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Palette.onAccent : Palette.textPrimary)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(Palette.accent).interactive() : .regular.interactive(), in: .capsule)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        MapTabView()
    }
}
