import UserNotifications
import os

/// Agenda os lembretes locais de água. Não guarda estado: quem decide quando chamar é o `WaterStore`.
struct ReminderScheduler {
    static let category = "WATER_REMINDER"
    static let addWaterAction = "ADD_WATER"

    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "com.dimitre.WaterTracker", category: "Lembretes")

    /// Registra o botão "Registrar" que aparece na notificação.
    func registerCategory() {
        let action = UNNotificationAction(identifier: Self.addWaterAction, title: "Registrar", options: [])
        let category = UNNotificationCategory(identifier: Self.category,
                                              actions: [action],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            log.error("Pedido de permissão de notificação falhou: \(error.localizedDescription)")
            return false
        }
    }

    /// Um lembrete por hora cheia, de `startHour` até `endHour`, a cada `intervalHours`.
    func schedule(startHour: Int, endHour: Int, intervalHours: Int) async {
        center.removeAllPendingNotificationRequests()
        let end = max(endHour, startHour)
        for hour in stride(from: startHour, through: end, by: max(intervalHours, 1)) {
            let content = UNMutableNotificationContent()
            content.title = "Hora de beber água"
            content.body = "Registre seu copo agora."
            content.categoryIdentifier = Self.category
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "water_\(hour)", content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                log.error("Não consegui agendar o lembrete das \(hour)h: \(error.localizedDescription)")
            }
        }
    }

    func cancel() {
        center.removeAllPendingNotificationRequests()
    }
}
