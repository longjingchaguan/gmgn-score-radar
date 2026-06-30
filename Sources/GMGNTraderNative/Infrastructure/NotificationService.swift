import Foundation
import AppKit
import UserNotifications
import os

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private var notified = Set<String>()
    private let logger = Logger(subsystem: "ai.gmgn.trader.native", category: "notification")

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyCandidateIfNeeded(_ decision: TradeDecision, chain: Chain, url: URL) {
        let score = decision.scoreBreakdown?.total ?? decision.priority ?? 0
        guard score >= 70 else { return }

        let key = "\(chain.rawValue)-\(decision.features.address)-\(score)"
        guard !notified.contains(key) else { return }
        notified.insert(key)

        let content = UNMutableNotificationContent()
        content.title = "\(decision.features.symbolSafe)：\(decision.humanPushHeadline)"
        content.body = decision.notificationBody
        content.sound = .default
        content.userInfo = ["url": url.absoluteString]

        let request = UNNotificationRequest(
            identifier: key,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let value = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: value)
        else {
            return
        }
        let started = Date()
        _ = await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        logger.info("notification_open_dispatched elapsed_ms=\(Int(Date().timeIntervalSince(started) * 1000), privacy: .public) url=\(url.absoluteString, privacy: .public)")
    }
}
