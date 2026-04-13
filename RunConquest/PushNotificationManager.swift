import Foundation
import UIKit
import UserNotifications

// MARK: - Push Notification Manager

@Observable
@MainActor
class PushNotificationManager {
    static let shared = PushNotificationManager()

    var deviceToken: String? = nil

    // MARK: - Registration

    func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func didRegister(tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
    }

    func saveTokenForPlayer(_ playerName: String) async {
        guard let token = deviceToken, !playerName.isEmpty else { return }
        await SupabaseService.shared.updateDeviceToken(playerName: playerName, token: token)
    }

    // MARK: - Local Notifications (attack alerts during run)

    func sendAttackNotification(attackerName: String, lang: AppLanguage) {
        let content = UNMutableNotificationContent()
        content.title = lang.t("⚔ TERRITORY CAPTURED", "⚔ ТЕРРИТОРИЯ ЗАХВАЧЕНА")
        content.body  = lang.t(
            "\(attackerName) just ran through your zone!",
            "\(attackerName) захватил вашу территорию!"
        )
        content.sound = .defaultCritical
        content.badge = 1
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    func sendZoneCapturedNotification(victimName: String, lang: AppLanguage) {
        let content = UNMutableNotificationContent()
        content.title = lang.t("⚔ ZONE ATTACKED", "⚔ ЗОНА АТАКОВАНА")
        content.body  = lang.t(
            "You captured \(victimName)'s territory!",
            "Вы захватили территорию \(victimName)!"
        )
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    // MARK: - Badge Reset

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }
}
