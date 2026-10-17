//
//  WelcomeView.swift
//  AppCasal
//

import SwiftUI

/// Shown while the app prepares the first screen. Same background color and logo,
/// at the same size and position, as the launch screen (`UILaunchScreen` in Info.plist),
/// so the system launch screen hands over without a visible jump.
struct WelcomeView: View {
    @State private var showsMessage = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(.launchBackground)
                .ignoresSafeArea()
            Image(.launchLogo)
                .accessibilityHidden(true)
                .overlay(alignment: .bottom) {
                    VStack(spacing: Spacing.s) {
                        Text("Um espaço só nosso")
                            .font(.sectionTitle)
                            .foregroundStyle(Palette.textPrimary)
                        ProgressView()
                            .tint(Palette.accentText)
                    }
                    .fixedSize()
                    .alignmentGuide(.bottom) { $0[.top] }
                    .opacity(showsMessage ? 1 : 0)
                }
        }
        // Brand colors on both appearances, matching the launch screen.
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Abrindo o espaço de vocês"))
        .task {
            // The message only appears if preparing takes noticeable time.
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                showsMessage = true
            }
        }
    }
}

#Preview {
    WelcomeView()
}
