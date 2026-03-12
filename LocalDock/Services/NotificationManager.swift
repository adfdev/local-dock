import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private var previousPorts: Set<Int> = []

    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func checkForChanges(currentPorts: [PortInfo]) {
        guard AppSettings.shared.showNotifications else { return }

        let currentSet = Set(currentPorts.map(\.port))

        let opened = currentSet.subtracting(previousPorts)
        let closed = previousPorts.subtracting(currentSet)

        for port in opened {
            if let info = currentPorts.first(where: { $0.port == port }) {
                sendNotification(
                    title: "Port \(port) opened",
                    body: "\(info.displayName) is now listening on port \(port)"
                )
            }
        }

        for port in closed {
            sendNotification(
                title: "Port \(port) closed",
                body: "Port \(port) is no longer in use"
            )
        }

        previousPorts = currentSet
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
