import Foundation

/// Um dia do gráfico de histórico.
struct DayRecord: Identifiable {
    let id = UUID()
    let label: String
    let ml: Int
    let isToday: Bool
}

/// Regras de hidratação sem nada de SwiftUI, HealthKit ou UserDefaults.
/// Fica separado do `WaterStore` para dar pra testar com `swift test`.
enum Hydration {
    /// 35 ml por kg, arredondado para múltiplos de 250 ml, entre 500 ml e 6 L.
    static func suggestedGoalMl(weightKg: Int) -> Int {
        let rounded = Int((Double(weightKg) * 35 / 250).rounded()) * 250
        return min(max(rounded, 500), 6000)
    }

    static func progress(totalMl: Int, goalMl: Int) -> Double {
        guard goalMl > 0 else { return 0 }
        return min(Double(totalMl) / Double(goalMl), 1.0)
    }

    /// Chave do dia no histórico, no formato `2026-11-16`.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Os últimos 7 dias, do mais antigo para hoje. O dia de hoje usa `todayMl`.
    static func last7Days(history: [String: Int],
                          todayMl: Int,
                          now: Date = Date(),
                          calendar: Calendar = .current) -> [DayRecord] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEEE"

        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            let ml = daysAgo == 0 ? todayMl : (history[dayKey(for: date, calendar: calendar)] ?? 0)
            return DayRecord(label: formatter.string(from: date).uppercased(), ml: ml, isToday: daysAgo == 0)
        }
    }

    /// Dias seguidos com a meta batida. Hoje conta se já bateu; senão a sequência de ontem continua viva.
    static func currentStreak(history: [String: Int],
                              todayMl: Int,
                              goalMl: Int,
                              now: Date = Date(),
                              calendar: Calendar = .current) -> Int {
        var count = todayMl >= goalMl ? 1 : 0
        var offset = 1
        while let date = calendar.date(byAdding: .day, value: -offset, to: now),
              (history[dayKey(for: date, calendar: calendar)] ?? 0) >= goalMl {
            count += 1
            offset += 1
        }
        return count
    }

    /// Média dos dias em que algo foi registrado. Dias zerados não entram na conta.
    static func weekAverageMl(of days: [DayRecord]) -> Int {
        let filled = days.map(\.ml).filter { $0 > 0 }
        return filled.isEmpty ? 0 : filled.reduce(0, +) / filled.count
    }
}
