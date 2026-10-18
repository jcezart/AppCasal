//
//  NotificationViews.swift
//  AppCasal
//

import SwiftUI
import UIKit

/// Explains why notifications matter before the system asks. Offered once, in
/// production only; afterwards the choice lives in Nosso espaço > Notificações.
struct NotificationPromptView: View {
    let environment: AppEnvironment

    @Environment(\.dismiss) private var dismiss
    private static let offeredKey = "notifications.promptOffered"

    static func shouldOffer(_ environment: AppEnvironment) -> Bool {
        environment.runMode == .production && !UserDefaults.standard.bool(forKey: offeredKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Não perca nenhum carinho")
                    .font(.displayTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Ative as notificações para saber quando seu par deixar um recadinho e para lembrar das datas especiais de vocês.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
            Button("Ativar notificações") {
                Task {
                    await NotificationSettingsView.enable(environment)
                    dismiss()
                }
            }
            .buttonStyle(.primary)
            Button("Agora não") { dismiss() }
                .buttonStyle(.soft)
        }
        .padding(Spacing.screen)
        .padding(.top, Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .canvasBackground()
        .presentationDetents([.medium, .large])
        .onAppear { UserDefaults.standard.set(true, forKey: Self.offeredKey) }
    }
}

/// Nosso espaço > Notificações: permission state and the partner-note preference.
struct NotificationSettingsView: View {
    let environment: AppEnvironment

    @Environment(\.scenePhase) private var scenePhase

    private var notifications: ReminderNotifications { environment.reminderNotifications }

    /// Asks for permission (once, by the system) and schedules everything that depends on it.
    static func enable(_ environment: AppEnvironment) async {
        _ = await environment.reminderNotifications.requestAuthorization()
        await environment.syncReminderNotifications()
        await environment.syncNoteAlerts()
    }

    var body: some View {
        @Bindable var noteAlerts = environment.noteAlerts
        Form {
            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: "heart.circle")
                        .font(.title)
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                    Text("Ative as notificações para o seu par te encher de carinho")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Um recadinho novo, um aniversário chegando: o iPhone avisa vocês dois.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.vertical, Spacing.xs)
                permissionRow
            }
            .listRowBackground(Palette.surface)

            if notifications.isAllowed {
                Section {
                    Toggle("Recadinhos do seu par", isOn: $noteAlerts.isEnabled)
                        .accessibilityIdentifier("notifications.notes")
                        .onChange(of: noteAlerts.isEnabled) {
                            Task { await environment.syncNoteAlerts() }
                        }
                    LabeledContent("Lembretes", value: String(localized: "Escolha em cada lembrete"))
                } footer: {
                    Text("Os avisos chegam pelo iCloud e podem levar alguns instantes, principalmente sem internet ou com o modo de economia de bateria.")
                }
                .listRowBackground(Palette.surface)
            }
            if let error = environment.noteAlerts.lastError, notifications.isAllowed {
                Section { Text(error).foregroundStyle(Palette.accentText) }
                    .listRowBackground(Palette.surface)
            }
        }
        .canvasBackground()
        .tint(Palette.accentText)
        .navigationTitle("Notificações")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notifications.refreshAuthorization() }
        .onChange(of: scenePhase) {
            // Back from Ajustes: the permission may have changed there.
            guard scenePhase == .active else { return }
            Task { await Self.enableIfAllowed(environment) }
        }
    }

    @ViewBuilder
    private var permissionRow: some View {
        switch notifications.authorization {
        case .notDetermined:
            Button("Ativar notificações") { Task { await Self.enable(environment) } }
                .accessibilityIdentifier("notifications.enable")
        case .denied:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("Desativadas nos Ajustes do iPhone", systemImage: "bell.slash")
                    .foregroundStyle(Palette.textPrimary)
                Button("Abrir Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        default:
            Label("Notificações ativadas", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Palette.success)
        }
    }

    private static func enableIfAllowed(_ environment: AppEnvironment) async {
        await environment.reminderNotifications.refreshAuthorization()
        await environment.syncReminderNotifications()
        await environment.syncNoteAlerts()
    }
}
