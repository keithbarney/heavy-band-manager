import SwiftUI
import UIKit
import EventKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var bandManager: BandManager
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var toastManager: ToastManager
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.scenePhase) private var scenePhase
    @State private var isRefreshingPracticeEvents = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountFinalAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile
                Section {
                    if let member = bandManager.currentMember {
                        HStack(spacing: 12) {
                            MemberAvatar(member: member, size: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(member.name).font(.headline)
                                    if bandManager.isLeader {
                                        Text("Organizer")
                                            .font(.caption2.bold())
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                if let email = authManager.user?.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Profile")
                }

                // MARK: - Scheduled practices on the device calendar
                Section {
                    if calendarManager.isAuthorized {
                        NavigationLink {
                            EditCalendarView()
                                .environmentObject(calendarManager)
                        } label: {
                            HStack {
                                Text("Practice calendar")
                                Spacer()
                                Circle()
                                    .fill(calendarManager.practiceCalendarColor)
                                    .frame(width: 14, height: 14)
                                Text(calendarManager.practiceCalendarName)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Button {
                            Task {
                                isRefreshingPracticeEvents = true
                                await bandManager.syncMissingCalendarEvents(calendarManager: calendarManager)
                                isRefreshingPracticeEvents = false
                            }
                        } label: {
                            Label("Refresh practice events", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isRefreshingPracticeEvents)
                    } else {
                        Button(action: handleCalendarTap) {
                            Label("Connect my calendar", systemImage: "calendar")
                        }
                    }
                } header: {
                    Text("Practices on my calendar")
                } footer: {
                    Text("Confirmed practices are added to this calendar. Refresh practice events to restore any missing events on this device.")
                }

                // MARK: - Appearance
                Section("Appearance") {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appearanceMode = mode
                            }
                        } label: {
                            HStack {
                                Label(mode.rawValue, systemImage: mode.sfSymbol)
                                    .foregroundStyle(Color.themeTextPrimary)
                                Spacer()
                                if appearanceMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.themeAccent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                // MARK: - Permissions
                Section("Permissions") {
                    PermissionRow(
                        title: "Notifications",
                        sfSymbol: "bell",
                        state: notificationPermissionState,
                        action: handleNotificationTap
                    )
                }

                // MARK: - Account
                Section {
                    Button(role: .destructive) {
                        Task {
                            bandManager.cleanup()
                            await authManager.signOut()
                        }
                    } label: {
                        Text("Sign Out")
                    }

                    Button(role: .destructive) {
                        showDeleteAccountConfirmation = true
                    } label: {
                        HStack {
                            Text("Delete Account")
                            if isDeletingAccount {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDeletingAccount)
                    .confirmationDialog(
                        "Delete your account?",
                        isPresented: $showDeleteAccountConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Continue", role: .destructive) {
                            showDeleteAccountFinalAlert = true
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This permanently deletes your account, your bands, members, availability, and scheduled practices. This cannot be undone.")
                    }
                    .alert("Permanently delete your account?", isPresented: $showDeleteAccountFinalAlert) {
                        Button("Delete Forever", role: .destructive) {
                            Task { await performDeleteAccount() }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("There is no way to recover this account or its data once deleted.")
                    }
                    .alert("Couldn't delete account", isPresented: Binding(
                        get: { deleteAccountError != nil },
                        set: { if !$0 { deleteAccountError = nil } }
                    )) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(deleteAccountError ?? "")
                    }
                }

                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(Color.themeTextPrimary)
                        Spacer()
                        Text("\(Bundle.main.marketingVersion) (\(Bundle.main.buildNumber))")
                            .foregroundStyle(Color.themeTextSecondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await refreshNotificationStatus()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    calendarManager.checkAuthorization()
                    Task { await refreshNotificationStatus() }
                }
            }
        }
    }

    // MARK: - Permission state

    private var calendarPermissionState: PermissionState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    private var notificationPermissionState: PermissionState {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    private func handleCalendarTap() {
        switch calendarPermissionState {
        case .granted, .denied:
            openSettings()
        case .notDetermined:
            Task { await calendarManager.requestAccess() }
        }
    }

    private func handleNotificationTap() {
#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
        calendarManager.previewNotificationsAuthorized.toggle()
        notificationStatus = calendarManager.previewNotificationsAuthorized ? .authorized : .denied
#else
        switch notificationPermissionState {
        case .granted, .denied:
            openSettings()
        case .notDetermined:
            Task {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                await refreshNotificationStatus()
            }
        }
#endif
    }

    private func refreshNotificationStatus() async {
#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
        notificationStatus = calendarManager.previewNotificationsAuthorized ? .authorized : .notDetermined
#else
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { notificationStatus = settings.authorizationStatus }
#endif
    }

    private func openSettings() {
#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
        toastManager.show("Device settings are simulated in this mock review")
#else
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
#endif
    }

    private func performDeleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        bandManager.cleanup()
        let success = await authManager.deleteAccount()
        if !success {
            deleteAccountError = authManager.error ?? "Please try again."
        }
    }


}

// MARK: - Permission Row

enum PermissionState {
    case granted, notDetermined, denied
}

private struct PermissionRow: View {
    let title: String
    let sfSymbol: String
    let state: PermissionState
    let action: () -> Void

    private var binding: Binding<Bool> {
        Binding(
            get: { state == .granted },
            set: { _ in action() }
        )
    }

    var body: some View {
        Toggle(isOn: binding) {
            Label(title, systemImage: sfSymbol)
        }
    }
}

extension Bundle {
    var marketingVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
