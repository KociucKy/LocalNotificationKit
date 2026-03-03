import Testing
import Foundation
import UserNotifications
@testable import LocalNotificationKit

// MARK: - NotificationTrigger Tests

@Suite("NotificationTrigger")
struct NotificationTriggerTests {

    // MARK: Time interval

    @Test("timeInterval trigger builds correct UNTimeIntervalNotificationTrigger")
    func timeIntervalTrigger() {
        let trigger = NotificationTrigger.timeInterval(30, repeats: false)
        let unTrigger = trigger.unNotificationTrigger as? UNTimeIntervalNotificationTrigger
        #expect(unTrigger != nil)
        #expect(unTrigger?.timeInterval == 30)
        #expect(unTrigger?.repeats == false)
    }

    @Test("Repeating timeInterval trigger sets repeats = true")
    func timeIntervalRepeatingTrigger() {
        let trigger = NotificationTrigger.timeInterval(120, repeats: true)
        let unTrigger = trigger.unNotificationTrigger as? UNTimeIntervalNotificationTrigger
        #expect(unTrigger?.repeats == true)
    }

    @Test("timeInterval trigger round-trips through UNNotificationTrigger")
    func timeIntervalRoundTrip() {
        let original = NotificationTrigger.timeInterval(90, repeats: false)
        let roundTripped = original.unNotificationTrigger.notificationTrigger
        #expect(roundTripped == original)
    }

    // MARK: Calendar

    @Test("Calendar trigger builds correct UNCalendarNotificationTrigger")
    func calendarTrigger() {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        let trigger = NotificationTrigger.calendar(components, repeats: true)
        let unTrigger = trigger.unNotificationTrigger as? UNCalendarNotificationTrigger
        #expect(unTrigger != nil)
        #expect(unTrigger?.repeats == true)
        #expect(unTrigger?.dateComponents.hour == 9)
    }

    @Test("Calendar trigger round-trips through UNNotificationTrigger")
    func calendarRoundTrip() {
        var components = DateComponents()
        components.weekday = 2 // Monday
        components.hour = 8
        let original = NotificationTrigger.calendar(components, repeats: true)
        let roundTripped = original.unNotificationTrigger.notificationTrigger
        #expect(roundTripped == original)
    }
}

// MARK: - LocalNotification Model Tests

@Suite("LocalNotification model")
struct LocalNotificationModelTests {

    @Test("Default id is a non-empty UUID string")
    func defaultID() {
        let n = LocalNotification(
            title: "Test",
            body: "Body",
            trigger: .timeInterval(10, repeats: false)
        )
        #expect(!n.id.isEmpty)
        #expect(UUID(uuidString: n.id) != nil)
    }

    @Test("All properties initialise correctly")
    func allProperties() {
        let trigger = NotificationTrigger.timeInterval(60, repeats: false)
        let n = LocalNotification(
            id: "test-id",
            title: "Title",
            subtitle: "Sub",
            body: "Body",
            userInfo: ["key": "value"],
            trigger: trigger,
            badge: 3,
            sound: .named("chime.wav"),
            categoryIdentifier: "REMINDER"
        )
        #expect(n.id == "test-id")
        #expect(n.title == "Title")
        #expect(n.subtitle == "Sub")
        #expect(n.body == "Body")
        #expect(n.userInfo["key"] == "value")
        #expect(n.trigger == trigger)
        #expect(n.badge == 3)
        #expect(n.sound == .named("chime.wav"))
        #expect(n.categoryIdentifier == "REMINDER")
    }

    @Test("UNNotificationRequest round-trip preserves all fields")
    func roundTripViaUNRequest() {
        let original = LocalNotification(
            id: "rt-id",
            title: "Round Trip",
            subtitle: "Sub",
            body: "Body text",
            userInfo: ["foo": "bar"],
            trigger: .timeInterval(120, repeats: false),
            badge: 1,
            sound: .named("ping.wav"),
            categoryIdentifier: "CAT"
        )
        let request = UNNotificationRequest.make(from: original)
        guard let recovered = request.localNotification else {
            Issue.record("localNotification returned nil")
            return
        }
        #expect(recovered.id == original.id)
        #expect(recovered.title == original.title)
        #expect(recovered.subtitle == original.subtitle)
        #expect(recovered.body == original.body)
        #expect(recovered.userInfo == original.userInfo)
        #expect(recovered.sound == original.sound)
        #expect(recovered.categoryIdentifier == original.categoryIdentifier)
    }

    @Test("nil subtitle is preserved through UNNotificationRequest")
    func nilSubtitleRoundTrip() {
        let original = LocalNotification(
            id: "no-sub",
            title: "Title",
            subtitle: nil,
            body: "Body",
            trigger: .timeInterval(10, repeats: false)
        )
        let request = UNNotificationRequest.make(from: original)
        let recovered = request.localNotification
        #expect(recovered?.subtitle == nil)
    }
}

// MARK: - NotificationSound Tests

@Suite("NotificationSound")
struct NotificationSoundTests {

    @Test(".default maps to UNNotificationSound.default")
    func defaultSound() {
        let sound = NotificationSound.default
        #expect(sound.unNotificationSound != nil)
    }

    @Test(".none maps to nil UNNotificationSound")
    func noneSound() {
        let sound = NotificationSound.none
        #expect(sound.unNotificationSound == nil)
    }

    @Test(".named produces a non-nil UNNotificationSound")
    func namedSound() {
        let sound = NotificationSound.named("custom.wav")
        #expect(sound.unNotificationSound != nil)
    }
}
