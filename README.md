# LocalNotificationKit

A Swift 6 compatible package for scheduling and managing local notifications on Apple platforms.

## Requirements

| Platform | Minimum version |
|---|---|
| iOS | 16.0 |
| macOS | 13.0 |
| tvOS | 16.0 |
| watchOS | 9.0 |

Swift 6 / Xcode 16 required.

## Products

| Product | Description |
|---|---|
| `LocalNotificationKit` | Core scheduling, models, and manager |
| `LocalNotificationKitDebugUI` | SwiftUI debug view for DevSettings screens |

## Installation

Add the package in Xcode via **File › Add Package Dependencies** or in `Package.swift`:

```swift
.package(url: "https://github.com/KociucKy/LocalNotificationKit.git", from: "1.0.0")
```

Add `LocalNotificationKit` to your main target and, optionally, `LocalNotificationKitDebugUI` to your debug target.

## Usage

### Request permission

```swift
import LocalNotificationKit

let granted = try await LocalNotificationManager.shared.requestAuthorization()
```

### Schedule notifications

```swift
// Fire once after 1 hour
let reminder = LocalNotification(
    title: "Reminder",
    body: "Don't forget to check in!",
    trigger: .timeInterval(60 * 60, repeats: false)
)
try await LocalNotificationManager.shared.schedule(reminder)

// Fire every Monday at 09:00
var components = DateComponents()
components.weekday = 2
components.hour = 9
components.minute = 0
let weekly = LocalNotification(
    title: "Weekly Check-in",
    body: "Time for your weekly review.",
    trigger: .calendar(components, repeats: true)
)
try await LocalNotificationManager.shared.schedule(weekly)

// Fire when entering a region (iOS only)
#if os(iOS)
import CoreLocation
let region = CLCircularRegion(
    center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12),
    radius: 200,
    identifier: "london-office"
)
region.notifyOnEntry = true
let geo = LocalNotification(
    title: "Welcome to the office",
    body: "You've arrived.",
    trigger: .location(NotificationRegion(region), repeats: false)
)
try await LocalNotificationManager.shared.schedule(geo)
#endif
```

### Fetch and cancel

```swift
// All pending notifications
let pending = await LocalNotificationManager.shared.pendingNotifications()

// Status of a specific notification
let status = await LocalNotificationManager.shared.status(for: reminder.id)
// → .pending / .delivered / .cancelled

// Cancel one
await LocalNotificationManager.shared.cancel(id: reminder.id)

// Cancel all
await LocalNotificationManager.shared.cancelAll()
```

### Dependency injection / testing

Conform to `LocalNotificationManaging` to inject a mock in unit tests:

```swift
final class MockManager: LocalNotificationManaging {
    var scheduled: [LocalNotification] = []

    func schedule(_ notification: LocalNotification) async throws {
        scheduled.append(notification)
    }
    // ... implement remaining protocol requirements
}
```

Pass it into any type that accepts `any LocalNotificationManaging`.

## Debug UI

Add `LocalNotificationKitDebugUI` to your debug target, then embed `NotificationDebugView` in your DevSettings screen:

```swift
#if DEBUG
import LocalNotificationKitDebugUI

struct DevSettingsView: View {
    var body: some View {
        NavigationStack {
            NotificationDebugView()
        }
    }
}
#endif
```

The view shows:
- Current notification permission status
- All **pending** notifications with trigger type, schedule, sound, badge, and full `userInfo`
- All **delivered** notifications
- Swipe-to-cancel/remove on individual rows
- A "Clear All" toolbar button
- Pull-to-refresh

## Models

### `LocalNotification`

```swift
public struct LocalNotification: Identifiable, Sendable, Hashable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var body: String
    public var userInfo: [String: String]
    public var trigger: NotificationTrigger
    public var badge: Int?
    public var sound: NotificationSound
    public var categoryIdentifier: String
}
```

### `NotificationTrigger`

```swift
public enum NotificationTrigger: Sendable, Hashable {
    case timeInterval(TimeInterval, repeats: Bool)
    case calendar(DateComponents, repeats: Bool)
    case location(NotificationRegion, repeats: Bool) // iOS only
}
```

### `NotificationSound`

```swift
public enum NotificationSound: Sendable, Hashable, Codable {
    case `default`
    case named(String)  // file must be in the app bundle
    case none
}
```

### `NotificationStatus`

```swift
public enum NotificationStatus: String, Sendable, CaseIterable, Hashable, Codable {
    case pending
    case delivered
    case cancelled
}
```

## Error handling

```swift
public enum LocalNotificationError: Error, Sendable, Equatable {
    case notAuthorized
    case schedulingFailed(underlying: any Error & Sendable)
    case repeatIntervalTooShort   // repeating time-interval trigger < 60 s
}
```

## Swift 6 compatibility

All public types are `Sendable`. The manager is isolated to `@MainActor`. Location region bridging uses `@unchecked Sendable` with a documented rationale (`CLRegion` is immutable after construction). No `@preconcurrency` suppressions are used in the core library.

## License

MIT
