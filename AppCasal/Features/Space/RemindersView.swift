//
//  RemindersView.swift
//  AppCasal
//

import CoreData
import SwiftUI
import UIKit

/// Lembretes: dates to remember (anniversaries and so on), soonest first.
struct RemindersView: View {
    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String

    @FetchRequest private var reminders: FetchedResults<Reminder>
    @State private var editor: ReminderEditorView.Mode?
    @State private var errorMessage: String?

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        _reminders = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Reminder.date, ascending: true)],
            predicate: NSPredicate(format: "space == %@ AND deletedAt == nil", space),
            animation: .default
        )
    }

    /// Upcoming first; past one-off reminders at the end.
    private var sorted: [Reminder] {
        let now = Date.now
        return reminders.sorted { lhs, rhs in
            let left = lhs.schedule?.daysUntilNext(from: now) ?? .max
            let right = rhs.schedule?.daysUntilNext(from: now) ?? .max
            return left < right
        }
    }

    private var showsAnniversarySuggestion: Bool {
        space.relationshipStart != nil && !reminders.contains { $0.repetition == .yearly && sameDay($0.date, space.relationshipStart) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                if showsAnniversarySuggestion, let start = space.relationshipStart {
                    Button {
                        editor = .create(ReminderDraft(title: String(localized: "Aniversário de namoro"), date: start, daysBefore: 3))
                    } label: {
                        InfoCard(
                            systemImage: "heart.circle",
                            title: "Lembrar do aniversário de namoro?",
                            message: "Toque para criar um lembrete todo ano a partir da data de início do relacionamento."
                        )
                    }
                    .buttonStyle(.plain)
                }
                if reminders.isEmpty {
                    EmptyStateView(
                        systemImage: "bell",
                        title: "Nenhum lembrete ainda",
                        message: "Aniversários, datas especiais e tudo o que vocês não querem esquecer.",
                        actionTitle: "Novo lembrete",
                        action: { editor = .create(ReminderDraft()) }
                    )
                } else {
                    LazyVStack(spacing: Spacing.s) {
                        ForEach(sorted) { reminder in
                            Button { editor = .edit(reminder) } label: {
                                ReminderRow(reminder: reminder)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Excluir", systemImage: "trash", role: .destructive) { delete(reminder) }
                            }
                            .accessibilityActions {
                                Button("Excluir") { delete(reminder) }
                            }
                        }
                    }
                }
                if environment.reminderNotifications.authorization == .denied, reminders.contains(where: \.notifies) {
                    ErrorBanner(
                        message: String(localized: "As notificações do app estão desativadas. Ative nos Ajustes para receber os lembretes."),
                        actionTitle: "Abrir Ajustes"
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
        .canvasBackground()
        .navigationTitle("Lembretes")
        .navigationSubtitle("Para nunca esquecer o que importa.")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Novo lembrete", systemImage: "plus") { editor = .create(ReminderDraft()) }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("reminders.add")
            }
        }
        .task { await environment.reminderNotifications.refreshAuthorization() }
        .sheet(item: $editor) { mode in
            ReminderEditorView(environment: environment, space: space, userRecordName: userRecordName, mode: mode)
        }
    }

    private func sameDay(_ lhs: Date?, _ rhs: Date?) -> Bool {
        guard let lhs, let rhs else { return false }
        let calendar = Calendar.current
        return calendar.dateComponents([.month, .day], from: lhs) == calendar.dateComponents([.month, .day], from: rhs)
    }

    private func delete(_ reminder: Reminder) {
        do {
            try environment.reminders.softDelete(reminder, by: userRecordName)
            errorMessage = nil
            Task { await environment.syncReminderNotifications() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ReminderRow: View {
    @ObservedObject var reminder: Reminder

    var body: some View {
        AdaptiveStack {
            Image(systemName: reminder.notifies ? "bell.fill" : "bell.slash")
                .foregroundStyle(reminder.notifies ? Palette.accentText : Palette.textSecondary)
                .frame(width: 36, height: 36)
                .background(Palette.surfaceMuted, in: .rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(reminder.title ?? "")
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text(dateLine)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                Text(noticeLine)
                    .font(.metadata)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
            if let days = reminder.schedule?.daysUntilNext(from: .now) {
                Text(days == 0 ? String(localized: "Hoje") : String(localized: "em \(days) d"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accentText)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(Palette.surfaceMuted, in: .capsule)
            }
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }

    private var dateLine: String {
        guard let date = reminder.date else { return "" }
        switch reminder.repetition {
        case .yearly:
            return String(localized: "Todo ano em \(date.formatted(.dateTime.day().month(.wide)))")
        case .monthly:
            return String(localized: "Todo mês no dia \(Calendar.current.component(.day, from: date))")
        case .none:
            return date.formatted(.dateTime.day().month(.wide).year())
        }
    }

    private var noticeLine: String {
        guard reminder.notifies else { return String(localized: "Sem notificação") }
        switch reminder.daysBefore {
        case 0: return String(localized: "Notificação no dia")
        case 1: return String(localized: "Notificação 1 dia antes")
        default: return String(localized: "Notificação \(reminder.daysBefore) dias antes")
        }
    }
}

/// Creates or edits a reminder: name, date, repetition, days before and notification.
struct ReminderEditorView: View {
    enum Mode: Identifiable {
        case create(ReminderDraft)
        case edit(Reminder)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let reminder): reminder.objectID.uriRepresentation().absoluteString
            }
        }
    }

    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String
    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReminderDraft
    @State private var errorMessage: String?
    @State private var isConfirmingDelete = false

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String, mode: Mode) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        self.mode = mode
        switch mode {
        case .create(let draft): _draft = State(initialValue: draft)
        case .edit(let reminder): _draft = State(initialValue: environment.reminders.draft(for: reminder))
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ex.: Aniversário de namoro", text: $draft.title)
                        .font(.cardTitle)
                        .accessibilityIdentifier("reminderEditor.title")
                    DatePicker("Data", selection: $draft.date, displayedComponents: .date)
                    Picker("Repetir", selection: $draft.repetition) {
                        Text("Não repetir").tag(ReminderSchedule.Repetition.none)
                        Text("Todo mês").tag(ReminderSchedule.Repetition.monthly)
                        Text("Todo ano").tag(ReminderSchedule.Repetition.yearly)
                    }
                    .accessibilityIdentifier("reminderEditor.repetition")
                }
                .listRowBackground(Palette.surface)
                Section {
                    Toggle("Receber notificação", isOn: $draft.notifies)
                        .accessibilityIdentifier("reminderEditor.notifies")
                    if draft.notifies {
                        Stepper(value: $draft.daysBefore, in: 0...ReminderSchedule.maximumDaysBefore(for: draft.repetition)) {
                            LabeledContent("Lembrar", value: daysBeforeText)
                        }
                    }
                } footer: {
                    if draft.notifies {
                        Text("A notificação chega às \(ReminderSchedule.notificationHour)h, neste iPhone e no do seu par.")
                    }
                }
                .listRowBackground(Palette.surface)
                if isEditing {
                    Section {
                        Button("Excluir lembrete", role: .destructive) { isConfirmingDelete = true }
                    }
                    .listRowBackground(Palette.surface)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Palette.accentText) }
                        .listRowBackground(Palette.surface)
                }
            }
            .canvasBackground()
            .tint(Palette.accentText)
            .navigationTitle(isEditing ? "Editar lembrete" : "Novo lembrete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", systemImage: "checkmark", role: .confirm) { Task { await save() } }
                        .disabled(!draft.isValid)
                        .accessibilityIdentifier("reminderEditor.save")
                }
            }
            .onChange(of: draft.repetition) {
                draft.daysBefore = min(draft.daysBefore, ReminderSchedule.maximumDaysBefore(for: draft.repetition))
            }
            .confirmationDialog("Excluir este lembrete?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Excluir", role: .destructive, action: delete)
            } message: {
                Text("Ele vai para Excluídos recentemente.")
            }
        }
    }

    private var daysBeforeText: String {
        switch draft.daysBefore {
        case 0: String(localized: "No dia")
        case 1: String(localized: "1 dia antes")
        default: String(localized: "\(draft.daysBefore) dias antes")
        }
    }

    private func save() async {
        do {
            switch mode {
            case .create:
                try environment.reminders.create(draft, in: space, by: userRecordName)
            case .edit(let reminder):
                try environment.reminders.update(reminder, with: draft, by: userRecordName)
            }
            // Permission is asked only when a reminder with notification is saved.
            if draft.notifies, !environment.isDemo {
                _ = await environment.reminderNotifications.requestAuthorization()
            }
            await environment.syncReminderNotifications()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        guard case .edit(let reminder) = mode else { return }
        do {
            try environment.reminders.softDelete(reminder, by: userRecordName)
            Task { await environment.syncReminderNotifications() }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
