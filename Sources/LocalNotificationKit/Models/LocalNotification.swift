import Foundation

/// The primary data model representing a local notification.
///
/// `LocalNotification` is a value type that fully conforms to `Sendable`,
/// making it safe to pass across actor and concurrency boundaries in Swift 6.
public struct LocalNotification: Identifiable, Sendable, Hashable {

    // MARK: - Properties

    /// A stable, unique identifier for this notification.
    /// Defaults to a newly generated UUID string.
    public var id: String

    /// The primary title displayed in the notification banner.
    public var title: String

    /// An optional subtitle displayed below the title.
    public var subtitle: String?

    /// The main body text of the notification.
    public var body: String

    /// A dictionary of `Sendable` key-value pairs attached to the notification.
    /// Accessible via `UNNotificationContent.userInfo` when the notification fires.
    public var userInfo: [String: String]

    /// When and how the notification should fire.
    public var trigger: NotificationTrigger

    /// The app icon badge number to set when the notification is delivered.
    /// Pass `nil` to leave the badge unchanged.
    public var badge: Int?

    /// The sound to play when the notification is delivered.
    public var sound: NotificationSound

    /// An optional category identifier used for actionable notifications.
    public var categoryIdentifier: String

    // MARK: - Initialisers

    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        body: String,
        userInfo: [String: String] = [:],
        trigger: NotificationTrigger,
        badge: Int? = nil,
        sound: NotificationSound = .default,
        categoryIdentifier: String = ""
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.userInfo = userInfo
        self.trigger = trigger
        self.badge = badge
        self.sound = sound
        self.categoryIdentifier = categoryIdentifier
    }
}
