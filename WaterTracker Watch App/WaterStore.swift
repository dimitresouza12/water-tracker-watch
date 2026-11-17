import SwiftUI
import Combine
import UserNotifications
import HealthKit

struct DayRecord: Identifiable {
    let id = UUID()
    let label: String
    let ml: Int
    let isToday: Bool
}

class WaterStore: ObservableObject {
    static let shared = WaterStore()

    @Published var totalMl: Int {
        didSet { save(); updateHistory() }
    }
    @Published var goalMl: Int {
        didSet { UserDefaults.standard.set(goalMl, forKey: "goal_ml") }
    }
    @Published var lastAmountMl: Int {
        didSet { UserDefaults.standard.set(lastAmountMl, forKey: "last_amount_ml") }
    }
    @Published var weightKg: Int {
        didSet { UserDefaults.standard.set(weightKg, forKey: "weight_kg") }
    }
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notifications_enabled")
            notificationsEnabled ? requestAndScheduleNotifications() : cancelNotifications()
        }
    }
    @Published var reminderIntervalHours: Int {
        didSet { UserDefaults.standard.set(reminderIntervalHours, forKey: "reminder_interval"); rescheduleIfNeeded() }
    }
    @Published var reminderStartHour: Int {
        didSet { UserDefaults.standard.set(reminderStartHour, forKey: "reminder_start"); rescheduleIfNeeded() }
    }
    @Published var reminderEndHour: Int {
        didSet { UserDefaults.standard.set(reminderEndHour, forKey: "reminder_end"); rescheduleIfNeeded() }
    }

    static let reminderCategory = "WATER_REMINDER"
    static let addWaterAction = "ADD_WATER"

    private let healthStore = HKHealthStore()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        f.locale = Locale(identifier: "pt_BR")
        return f
    }()

    init() {
        let defaults = UserDefaults.standard
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

        let today = Calendar.current.startOfDay(for: Date())
        let lastReset = defaults.object(forKey: "last_reset_date") as? Date ?? Date.distantPast

        if today > lastReset {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let yesterdayKey = Self.dateFormatter.string(from: yesterday)
            let lastTotal = defaults.integer(forKey: "water_ml")
            if lastTotal > 0 {
                var h = (defaults.dictionary(forKey: "water_history") as? [String: Int]) ?? [:]
                h[yesterdayKey] = lastTotal
                defaults.set(h, forKey: "water_history")
            }
            defaults.set(0, forKey: "water_ml")
            defaults.set(today, forKey: "last_reset_date")
        }

        self.totalMl = defaults.integer(forKey: "water_ml")
        registerNotificationCategory()
        requestHealthKitPermission()
    }

    var progress: Double { min(Double(totalMl) / Double(goalMl), 1.0) }
    var isGoalReached: Bool { totalMl >= goalMl }

    /// 35 ml por kg, arredondado para múltiplos de 250 ml.
    var suggestedGoalMl: Int {
        let rounded = Int((Double(weightKg) * 35 / 250).rounded()) * 250
        return min(max(rounded, 500), 6000)
    }

    func add(ml: Int) {
        lastAmountMl = ml
        totalMl += ml
        saveToHealthKit(ml: Double(ml))
        WKInterfaceDevice.current().play(isGoalReached ? .success : .click)
    }

    func remove(ml: Int) {
        totalMl = max(0, totalMl - ml)
        WKInterfaceDevice.current().play(.directionDown)
    }

    private var storedHistory: [String: Int] {
        (UserDefaults.standard.dictionary(forKey: "water_history") as? [String: Int]) ?? [:]
    }

    private func updateHistory() {
        var h = storedHistory
        h[Self.dateFormatter.string(from: Date())] = totalMl
        UserDefaults.standard.set(h, forKey: "water_history")
    }

    var last7Days: [DayRecord] {
        let calendar = Calendar.current
        let history = storedHistory
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            let key = Self.dateFormatter.string(from: date)
            let ml = daysAgo == 0 ? totalMl : (history[key] ?? 0)
            return DayRecord(label: Self.dayFormatter.string(from: date).uppercased(), ml: ml, isToday: daysAgo == 0)
        }
    }

    /// Dias seguidos com a meta batida. Hoje conta se já bateu; senão a sequência de ontem continua viva.
    var currentStreak: Int {
        let calendar = Calendar.current
        let history = storedHistory
        var count = isGoalReached ? 1 : 0
        var offset = 1
        while let date = calendar.date(byAdding: .day, value: -offset, to: Date()),
              (history[Self.dateFormatter.string(from: date)] ?? 0) >= goalMl {
            count += 1
            offset += 1
        }
        return count
    }

    /// Média dos dias da última semana em que algo foi registrado.
    var weekAverageMl: Int {
        let filled = last7Days.map(\.ml).filter { $0 > 0 }
        return filled.isEmpty ? 0 : filled.reduce(0, +) / filled.count
    }

    private func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let waterType = HKQuantityType(.dietaryWater)
        healthStore.requestAuthorization(toShare: [waterType], read: [waterType]) { _, _ in }
    }

    private func saveToHealthKit(ml: Double) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let waterType = HKQuantityType(.dietaryWater)
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())
        healthStore.save(sample) { _, _ in }
    }

    private func registerNotificationCategory() {
        let action = UNNotificationAction(identifier: Self.addWaterAction, title: "Registrar", options: [])
        let category = UNNotificationCategory(identifier: Self.reminderCategory,
                                              actions: [action],
                                              intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func requestAndScheduleNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted { self.scheduleNotifications() }
                else { self.notificationsEnabled = false }
            }
        }
    }

    private func rescheduleIfNeeded() {
        if notificationsEnabled { scheduleNotifications() }
    }

    private func scheduleNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let end = max(reminderEndHour, reminderStartHour)
        for hour in stride(from: reminderStartHour, through: end, by: reminderIntervalHours) {
            let content = UNMutableNotificationContent()
            content.title = "Hora de beber água"
            content.body = "Registre seu copo agora."
            content.categoryIdentifier = Self.reminderCategory
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let req = UNNotificationRequest(identifier: "water_\(hour)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(req)
        }
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func save() {
        UserDefaults.standard.set(totalMl, forKey: "water_ml")
    }
}

/// Trata o botão "Registrar" das notificações de lembrete.
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == WaterStore.addWaterAction {
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
