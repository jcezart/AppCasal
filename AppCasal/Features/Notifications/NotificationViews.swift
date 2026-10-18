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
        PromptScaffold(
            systemImage: "heart.text.square",
            title: "Não perca nenhum carinho",
            message: "Ative as notificações para saber quando seu par deixar um recadinho e para lembrar das datas especiais de vocês."
        ) {
            Button("Ativar notificações") {
                Task {
                    await NotificationSettingsView.enable(environment)
                    dismiss()
                }
            }
            .buttonStyle(.primary)
            Button("Agora não") { dismiss() }
                .buttonStyle(.text)
        }
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
        await environment.syncMomentNotifications()
    }

    var body: some View {
        @Bindable var noteAlerts = environment.noteAlerts
        @Bindable var moments = environment.momentNotifications
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
            Section {
                Toggle("Lembrete da pergunta do dia", isOn: momentToggle($moments.preferences.dailyQuestion))
                    .accessibilityIdentifier("notifications.dailyQuestion")
                if moments.preferences.dailyQuestion || moments.preferences.weeklyIdea || moments.preferences.memoryAnniversaries {
                    DatePicker("Horário", selection: timeBinding($moments.preferences.minutes), displayedComponents: .hourAndMinute)
                }
                Toggle("Ideia de encontro às sextas", isOn: momentToggle($moments.preferences.weeklyIdea))
                Toggle("Aniversário das memórias", isOn: momentToggle($moments.preferences.memoryAnniversaries))
            } header: {
                Text("Hoje, nós dois")
            } footer: {
                Text("No máximo um lembrete por dia, só neste iPhone; a pergunta do dia vem primeiro. O lembrete some quando você responde. Avisos de que seu par respondeu ainda não estão disponíveis: vocês veem isso no app.")
            }
            .listRowBackground(Palette.surface)
            .onChange(of: moments.preferences) {
                Task { await environment.syncMomentNotifications() }
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

    /// Turning a reminder on asks for permission first, in context, when never asked.
    private func momentToggle(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding {
            binding.wrappedValue
        } set: { isOn in
            binding.wrappedValue = isOn
            if isOn, notifications.authorization == .notDetermined {
                Task { await Self.enable(environment) }
            }
        }
    }

    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(byAdding: .minute, value: minutes.wrappedValue, to: Calendar.current.startOfDay(for: .now)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes.wrappedValue = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
        }
    }

    private static func enableIfAllowed(_ environment: AppEnvironment) async {
        await environment.reminderNotifications.refreshAuthorization()
        await environment.syncReminderNotifications()
        await environment.syncNoteAlerts()
        await environment.syncMomentNotifications()
    }
}
