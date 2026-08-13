// NotificationManager — 일일 리마인더 알림 (PRD 3.5) 매일 00:00 KST
import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                DebugLogger.shared.log(.error, "알림", "권한 요청 실패", meta: ["error": String(describing: error)])
            } else {
                DebugLogger.shared.feature("알림", "권한 상태", meta: ["granted": granted])
            }
        }
    }

    func syncWithSetting(_ enabled: Bool) {
        if enabled {
            requestAuthorizationIfNeeded()
            scheduleDaily()
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            DebugLogger.shared.feature("알림", "예약 알림 모두 취소됨")
        }
    }

    // 매일 00:00 KST 반복 알림
    func scheduleDaily() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = "글마을 달인"
        content.body = "오늘의 에피소드가 기다리고 있어요! 🔥"
        content.sound = .default

        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-episode", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                DebugLogger.shared.log(.error, "알림", "예약 실패", meta: ["error": String(describing: error)])
            } else {
                DebugLogger.shared.feature("알림", "매일 00:00 KST 예약됨")
            }
        }
    }
}