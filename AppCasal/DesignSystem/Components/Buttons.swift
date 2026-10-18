//
//  Buttons.swift
//  AppCasal
//

import SwiftUI

/// Filled terracotta button for the main action of a screen ("Nova memória").
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, Spacing.m)
            .background(Palette.accent, in: .rect(cornerRadius: Radius.button, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Soft secondary button ("Como chegar").
struct SoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.accentText)
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.m)
            .background(Palette.surfaceMuted, in: .rect(cornerRadius: Radius.button, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// For labels that already draw their own shape (the "Adicionar" photo tile). A custom
/// style, so "Formatos dos Botões" (Ajustes > Acessibilidade) does not add a second
/// background around that shape; the tile itself is the visible button shape.
struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SoftButtonStyle {
    static var soft: SoftButtonStyle { SoftButtonStyle() }
}

extension ButtonStyle where Self == TileButtonStyle {
    static var tile: TileButtonStyle { TileButtonStyle() }
}

#Preview {
    VStack(spacing: Spacing.m) {
        Button("Nova memória", systemImage: "plus") {}
            .buttonStyle(.primary)
        Button("Como chegar", systemImage: "location.fill") {}
            .buttonStyle(.soft)
        Button("Desativado") {}
            .buttonStyle(.primary)
            .disabled(true)
    }
    .padding()
    .background(Palette.canvas)
}
