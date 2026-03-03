import SwiftUI
import UserNotifications
import LocalNotificationKit

/// A single row in `NotificationDebugView` showing the details of one notification.
@MainActor
struct NotificationRowView: View {

    let notification: LocalNotification
    let status: NotificationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title + status badge
            HStack(alignment: .firstTextBaseline) {
                Text(notification.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                StatusBadge(status: status)
            }

            // Subtitle
            if let subtitle = notification.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Body
            if !notification.body.isEmpty {
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            // Trigger summary
            HStack(spacing: 12) {
                Label(notification.trigger.debugSummary, systemImage: notification.trigger.systemImageName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let badge = notification.badge {
                    Label("\(badge)", systemImage: "app.badge")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Label(notification.sound.debugSummary, systemImage: "speaker.wave.2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // ID
            Text("ID: \(notification.id)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            // userInfo (if any)
            if !notification.userInfo.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(notification.userInfo.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        Text("\(key): \(value)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - StatusBadge

private struct StatusBadge: View {
    let status: NotificationStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.badgeColor.opacity(0.15))
            .foregroundStyle(status.badgeColor)
            .clipShape(Capsule())
    }
}

// MARK: - Helpers

private extension NotificationStatus {
    var badgeColor: Color {
        switch self {
        case .pending:   return .orange
        case .delivered: return .green
        case .cancelled: return .red
        }
    }
}

private extension NotificationTrigger {
    var debugSummary: String {
        switch self {
        case .timeInterval(let interval, let repeats):
            let formatted = Duration.seconds(interval).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
            return repeats ? "Every \(formatted)" : "In \(formatted)"
        case .calendar(let components, let repeats):
            let desc = components.debugDescription
            return repeats ? "Repeats: \(desc)" : "At: \(desc)"
        #if os(iOS)
        case .location(let region, let repeats):
            return repeats ? "Region (repeat): \(region.clRegion.identifier)" : "Region: \(region.clRegion.identifier)"
        #endif
        }
    }

    var systemImageName: String {
        switch self {
        case .timeInterval: return "timer"
        case .calendar:     return "calendar"
        #if os(iOS)
        case .location:     return "location"
        #endif
        }
    }
}

private extension NotificationSound {
    var debugSummary: String {
        switch self {
        case .default:      return "Default"
        case .named(let n): return n
        case .none:         return "Silent"
        }
    }
}
