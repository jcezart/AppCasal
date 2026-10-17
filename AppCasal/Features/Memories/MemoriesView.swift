//
//  MemoriesView.swift
//  AppCasal
//

import SwiftUI

/// Memórias: the couple's timeline. Content arrives in the memories increment.
struct MemoriesView: View {
    var body: some View {
        ScrollView {
            EmptyStateView(
                systemImage: "photo.on.rectangle.angled",
                title: "Nenhuma memória ainda",
                message: "Guardem aqui os momentos de vocês, com fotos, data e lugar."
            )
            .padding(.top, Spacing.xxxl)
        }
        .canvasBackground()
        .navigationTitle("Memórias")
        .navigationSubtitle("Nossos momentos, para sempre.")
    }
}

#Preview {
    NavigationStack {
        MemoriesView()
    }
}
