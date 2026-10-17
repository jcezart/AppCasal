//
//  GoalsView.swift
//  AppCasal
//

import SwiftUI

/// Metas: in progress and completed goals. Content arrives in the goals increment.
struct GoalsView: View {
    enum Filter: Hashable {
        case inProgress
        case completed
    }

    @State private var filter = Filter.inProgress

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                PillSegmentedControl(selection: $filter, options: [
                    .init(value: .inProgress, title: "Em andamento"),
                    .init(value: .completed, title: "Concluídas"),
                ])
                if filter == .inProgress {
                    EmptyStateView(
                        systemImage: "target",
                        title: "Nenhuma meta ainda",
                        message: "Viagens, planos e conquistas, com etapas e prazo."
                    )
                } else {
                    EmptyStateView(
                        systemImage: "checkmark.seal",
                        title: "Nenhuma meta concluída",
                        message: "As metas que vocês concluírem ficam guardadas aqui."
                    )
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
        .canvasBackground()
        .navigationTitle("Nossos planos")
        .navigationSubtitle("Sonhos que se constroem juntos.")
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
}
