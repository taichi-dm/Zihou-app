import SwiftUI
import UserNotifications
import os.log

@Observable final class WorkTimeNotifier {
    @MainActor var isWorking = false

    private let notificationCenter = UNUserNotificationCenter.current()

    private let logger = Logger()

    init() {
        Task {
            try await requestAuthorizationIfNeeded()
        }
    }

    func startWork() {
        Task.detached {
            await MainActor.run {
                self.isWorking = true
            }
            try await self.requestAuthorizationIfNeeded()
            try await self.scheduleNotifications()
        }
    }

    func endWork() {
        Task { @MainActor in
            isWorking = false
        }
        cancelNotifications()
    }

    private func requestAuthorizationIfNeeded() async throws {
        let status = await notificationCenter.notificationSettings()

        switch status.authorizationStatus {
        case .authorized, .provisional:
            logger.info("通知の許可が得られています。")
        case .denied:
            logger.info("通知を拒否されています。設定アプリに遷移します。")
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        case .notDetermined:
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await notificationCenter.requestAuthorization(options: options)

            guard granted else {
                logger.error("通知の許可が得られませんでした")
                return
            }

            logger.info("通知の許諾が取れました。")
        case .ephemeral:
            logger.info("App Clip用の通知許可が取れています")
        @unknown default:
            logger.error("実装のアップデートが必要です。")
        }
    }

    private func scheduleNotifications() async throws {
        let calendar = Calendar.current
        let now = Date()

        for hour in 1...8 {
            let content = UNMutableNotificationContent()
            content.title = "Zihou"
            content.body = "⌛️ \(hour)時間が経過しました。散歩して身体を動かしましょう"
            content.sound = .default

            let components = calendar.dateComponents([.hour, .minute, .second], from: now.addingTimeInterval(TimeInterval(hour * 10)))
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(identifier: "workTime-\(hour)", content: content, trigger: trigger)
            try await notificationCenter.add(request)
        }
    }

    private func cancelNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
}

struct ContentView: View {
    @State private var notifier = WorkTimeNotifier()

    var body: some View {
        VStack(spacing: 20) {
            Text(notifier.isWorking ? "勤務中" : "勤務外")
                .font(.title)

            Button(action: {
                if notifier.isWorking {
                    notifier.endWork()
                } else {
                    notifier.startWork()
                }
            }) {
                Text(notifier.isWorking ? "退勤" : "出勤")
                    .padding()
                    .background(notifier.isWorking ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .sensoryFeedback(.selection, trigger: notifier.isWorking)
    }
}

#Preview {
    ContentView()
}
