import SwiftUI
import Combine
import UserNotifications

/// Estado do app: quanto bebi hoje, a meta e as preferências.
/// A conta das regras fica em `Hydration`, o Saúde em `HealthKitService` e os lembretes em `ReminderScheduler`.
final class WaterStore: ObservableObject {
    static let shared = WaterStore()

    @Published var totalMl: Int {
        didSet { save(); updateHistory() }
    }
    @Published var goalMl: Int {
        didSet { defaults.set(goalMl, forKey: "goal_ml") }
    }
    @Published var lastAmountMl: Int {
        didSet { defaults.set(lastAmountMl, forKey: "last_amount_ml") }
    }
    @Published var weightKg: Int {
        didSet { defaults.set(weightKg, forKey: "weight_kg") }
    }
    @Published var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: "notifications_enabled")
            if notificationsEnabled { requestAndScheduleNotifications() } else { reminders.cancel() }
        }
    }
    @Published var reminderIntervalHours: Int {
        didSet { defaults.set(reminderIntervalHours, forKey: "reminder_interval"); rescheduleIfNeeded() }
    }
    @Published var reminderStartHour: Int {
        didSet { defaults.set(reminderStartHour, forKey: "reminder_start"); rescheduleIfNeeded() }
    }
    @Published var reminderEndHour: Int {
        didSet { defaults.set(reminderEndHour, forKey: "reminder_end"); rescheduleIfNeeded() }
    }

    private let defaults: UserDefaults
    private let health = HealthKitService()
    private let reminders = ReminderScheduler()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedGoal = defaults.integer(forKey: "goal_ml")
        self.goalMl = savedGoal > 0 ? savedGoal : 2000
        let savedAmount = defaults.integer(forKey: "last_amount_ml")
        self.lastAmountMl = savedAmount > 0 ? savedAmount : 200
        let savedWeight = defaults.integer(forKey: "weight_kg")
        self.weightKg = savedWeight > 0 ? savedWeight : 70
        self.notificationsEnabled = defaults.bool(forKey: "notifications_enabled")
        let savedInterval = defaults.integer(forKey: "reminder_interval")
        self.reminderIntervalHours = savedInterval > 0 ? savedInterval : 2
        self.reminderStartHour = defaults.object(forKey: "reminder_start") as? Int ?? 8
        self.reminderEndHour = defaults.object(forKey: "reminder_end") as? Int ?? 20

        // Virou o dia: o total de ontem vai para o histórico e o de hoje começa do zero.
        let today = Calendar.current.startOfDay(for: Date())
        let lastReset = defaults.object(forKey: "last_reset_date") as? Date ?? Date.distantPast

        if today > lastReset {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let lastTotal = defaults.integer(forKey: "water_ml")
            if lastTotal > 0 {
                var history = (defaults.dictionary(forKey: "water_history") as? [String: Int]) ?? [:]
                history[Hydration.dayKey(for: yesterday)] = lastTotal
                defaults.set(history, forKey: "water_history")
            }
            defaults.set(0, forKey: "water_ml")
            defaults.set(today, forKey: "last_reset_date")
        }

        self.totalMl = defaults.integer(forKey: "water_ml")
        reminders.registerCategory()
        Task { await health.requestAuthorization() }
    }

    var progress: Double { Hydration.progress(totalMl: totalMl, goalMl: goalMl) }
    var isGoalReached: Bool { totalMl >= goalMl }
    var suggestedGoalMl: Int { Hydration.suggestedGoalMl(weightKg: weightKg) }

    var last7Days: [DayRecord] {
        Hydration.last7Days(history: storedHistory, todayMl: totalMl)
    }

    var currentStreak: Int {
        Hydration.currentStreak(history: storedHistory, todayMl: totalMl, goalMl: goalMl)
    }

    var weekAverageMl: Int { Hydration.weekAverageMl(of: last7Days) }

    func add(ml: Int) {
        lastAmountMl = ml
        totalMl += ml
        Task { await health.saveWater(ml: ml) }
        WKInterfaceDevice.current().play(isGoalReached ? .success : .click)
    }

    func remove(ml: Int) {
        totalMl = max(0, totalMl - ml)
        WKInterfaceDevice.current().play(.directionDown)
    }

    // MARK: Persistência

    private var storedHistory: [String: Int] {
        (defaults.dictionary(forKey: "water_history") as? [String: Int]) ?? [:]
    }

    private func updateHistory() {
        var history = storedHistory
        history[Hydration.dayKey(for: Date())] = totalMl
        defaults.set(history, forKey: "water_history")
    }

    private func save() {
        defaults.set(totalMl, forKey: "water_ml")
    }

    // MARK: Lembretes

    // As propriedades são @Published, então tudo que lê ou muda elas roda na main thread.

    private func requestAndScheduleNotifications() {
        Task { @MainActor in
            if await reminders.requestAuthorization() {
                await scheduleReminders()
            } else {
                notificationsEnabled = false
            }
        }
    }

    private func rescheduleIfNeeded() {
        guard notificationsEnabled else { return }
        Task { @MainActor in await scheduleReminders() }
    }

    @MainActor
    private func scheduleReminders() async {
        let (start, end, interval) = (reminderStartHour, reminderEndHour, reminderIntervalHours)
        await reminders.schedule(startHour: start, endHour: end, intervalHours: interval)
    }
}

/// Trata o botão "Registrar" das notificações de lembrete.
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == ReminderScheduler.addWaterAction {
            DispatchQueue.main.async {
                let store = WaterStore.shared
                store.add(ml: store.lastAmountMl)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
