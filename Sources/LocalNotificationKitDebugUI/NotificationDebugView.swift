import SwiftUI
import UserNotifications
import LocalNotificationKit

/// A SwiftUI view that displays all pending and delivered local notifications.
///
/// Intended for embedding in a DevSettings / debug screen in `#if DEBUG` builds:
///
/// ```swift
/// #if DEBUG
/// import LocalNotificationKitDebugUI
///
/// struct DevSettingsView: View {
///     var body: some View {
///         NotificationDebugView()
///     }
/// }
/// #endif
/// ```
///
/// The view uses `LocalNotificationManager.shared` by default but accepts any
/// `LocalNotificationManaging`-conforming object for testability.
@MainActor
public struct NotificationDebugView: View {

    // MARK: - State

    private let manager: any LocalNotificationManaging

    @State private var pending: [LocalNotification] = []
    @State private var delivered: [LocalNotification] = []
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isLoading = false
    @State private var errorMessage: String?

    // MARK: - Init

    public init(manager: any LocalNotificationManaging = LocalNotificationManager.shared) {
        self.manager = manager
    }

    // MARK: - Body

    public var body: some View {
        List {
            // Authorization section
            Section {
                AuthorizationRow(status: authStatus)
            } header: {
                Text("Permissions")
            }

            // Pending
            Section {
                if pending.isEmpty {
                    Text("No pending notifications")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(pending) { notification in
                        NotificationRowView(notification: notification, status: .pending)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await cancel(id: notification.id) }
                                } label: {
                                    Label("Cancel", systemImage: "bell.slash")
                                }
                            }
                    }
                }
            } header: {
                HStack {
                    Text("Pending (\(pending.count))")
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }

            // Delivered
            Section {
                if delivered.isEmpty {
                    Text("No delivered notifications")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(delivered) { notification in
                        NotificationRowView(notification: notification, status: .delivered)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await cancel(id: notification.id) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                Text("Delivered (\(delivered.count))")
            }

            // Error banner
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Local Notifications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }

            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    Task {
                        await manager.cancelAll()
                        await load()
                    }
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(pending.isEmpty && delivered.isEmpty)
            }
        }
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
    }

    // MARK: - Helpers

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let pendingResult = manager.pendingNotifications()
        async let deliveredResult = manager.deliveredNotifications()
        async let authResult = manager.authorizationStatus()

        pending = await pendingResult
        delivered = await deliveredResult
        authStatus = await authResult
    }

    private func cancel(id: String) async {
        await manager.cancel(id: id)
        await load()
    }
}

// MARK: - Preview

#if DEBUG

/// A canned `LocalNotificationManaging` implementation used exclusively in Xcode Previews.
@MainActor
private final class PreviewNotificationManager: LocalNotificationManaging {

    var pending: [LocalNotification]
    var delivered: [LocalNotification]
    var status: UNAuthorizationStatus

    init(
        pending: [LocalNotification] = [],
        delivered: [LocalNotification] = [],
        status: UNAuthorizationStatus = .authorized
    ) {
        self.pending = pending
        self.delivered = delivered
        self.status = status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func schedule(_ notification: LocalNotification) async throws { pending.append(notification) }
    func scheduleAll(_ notifications: [LocalNotification]) async throws { pending.append(contentsOf: notifications) }
    func pendingNotifications() async -> [LocalNotification] { pending }
    func deliveredNotifications() async -> [LocalNotification] { delivered }
    func status(for id: String) async -> NotificationStatus {
        if pending.contains(where: { $0.id == id }) { return .pending }
        if delivered.contains(where: { $0.id == id }) { return .delivered }
        return .cancelled
    }
    func cancel(id: String) async { pending.removeAll { $0.id == id }; delivered.removeAll { $0.id == id } }
    func cancel(ids: [String]) async { for id in ids { await cancel(id: id) } }
    func cancelAll() async { pending.removeAll(); delivered.removeAll() }
}

private extension LocalNotification {
    // Convenience factory for concise preview fixtures
    static func preview(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        body: String,
        trigger: NotificationTrigger,
        sound: NotificationSound = .default,
        badge: Int? = nil,
        userInfo: [String: String] = [:]
    ) -> LocalNotification {
        LocalNotification(
            id: id,
            title: title,
            subtitle: subtitle,
            body: body,
            userInfo: userInfo,
            trigger: trigger,
            badge: badge,
            sound: sound
        )
    }
}

#Preview("Authorized — mixed notifications") {
    let weeklyComponents: DateComponents = {
        var c = DateComponents()
        c.hour = 9
        c.minute = 0
        c.weekday = 2 // Monday
        return c
    }()

    let manager = PreviewNotificationManager(
        pending: [
            .preview(
                title: "Daily Standup",
                subtitle: "Engineering",
                body: "Time for the daily standup meeting.",
                trigger: .calendar(weeklyComponents, repeats: true),
                sound: .default,
                userInfo: ["channel": "engineering", "type": "standup"]
            ),
            .preview(
                title: "Drink Water",
                body: "Stay hydrated!",
                trigger: .timeInterval(60 * 60, repeats: true),
                sound: .named("water_drop.wav"),
                badge: 1
            ),
            .preview(
                title: "Silent Reminder",
                body: "This notification plays no sound.",
                trigger: .timeInterval(30 * 60, repeats: false),
                sound: .none
            )
        ],
        delivered: [
            .preview(
                title: "Good Morning",
                body: "Rise and shine! Have a great day.",
                trigger: .timeInterval(1, repeats: false)
            )
        ],
        status: .authorized
    )

    NavigationStack {
        NotificationDebugView(manager: manager)
    }
}

#Preview("Denied permissions") {
    NavigationStack {
        NotificationDebugView(manager: PreviewNotificationManager(status: .denied))
    }
}

#Preview("Empty state") {
    NavigationStack {
        NotificationDebugView(manager: PreviewNotificationManager(status: .authorized))
    }
}

#endif

// MARK: - AuthorizationRow

private struct AuthorizationRow: View {
    let status: UNAuthorizationStatus

    var body: some View {
        HStack {
            Image(systemName: status.systemImageName)
                .foregroundStyle(status.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notification Permission")
                    .font(.subheadline)
                Text(status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - UNAuthorizationStatus helpers

private extension UNAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied:        return "Denied"
        case .authorized:    return "Authorized"
        case .provisional:   return "Provisional"
        case .ephemeral:     return "Ephemeral"
        @unknown default:    return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied:                                return .red
        case .notDetermined:                         return .orange
        @unknown default:                            return .gray
        }
    }

    var systemImageName: String {
        switch self {
        case .authorized, .provisional, .ephemeral: return "checkmark.shield"
        case .denied:                                return "xmark.shield"
        case .notDetermined:                         return "questionmark.shield"
        @unknown default:                            return "shield"
        }
    }
}
