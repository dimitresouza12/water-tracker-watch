import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var store: WaterStore

    private var days: [DayRecord] { store.last7Days }
    private var hasData: Bool { days.contains { $0.ml > 0 } }
    private var streak: Int { store.currentStreak }

    private func barColor(_ day: DayRecord) -> Color {
        if day.isToday { return Palette.cyan }
        return day.ml >= store.goalMl ? Palette.mint : Palette.brightBlue.opacity(0.55)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Últimos 7 dias")
                    .font(.footnote.weight(.semibold))

                streakRow

                if hasData {
                    chart
                    Text("Média \(formatVolume(store.weekAverageMl))/dia")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 20)
        }
        .appBackground()
    }

    private var streakRow: some View {
        HStack(spacing: 6) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .foregroundStyle(streak > 0 ? Palette.flame : .white.opacity(0.5))
            Text(streak == 0 ? "Sem sequência" : streak == 1 ? "1 dia na meta" : "\(streak) dias seguidos")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        let top = max(store.goalMl, days.map(\.ml).max() ?? 0)
        return VStack(spacing: 2) {
            Chart {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    BarMark(x: .value("Dia", index),
                            y: .value("ml", max(day.ml, top / 40)),
                            width: .fixed(14))
                        .foregroundStyle(barColor(day))
                        .cornerRadius(4)
                }
                RuleMark(y: .value("Meta", store.goalMl))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .chartXScale(domain: -0.6...(Double(days.count) - 0.4))
            .chartYScale(domain: 0...top)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: Array(0..<days.count)) { value in
                    AxisValueLabel {
                        if let index = value.as(Int.self), days.indices.contains(index) {
                            Text(days[index].label)
                                .font(.caption2.weight(days[index].isToday ? .bold : .regular))
                                .foregroundColor(days[index].isToday ? Palette.cyan : .white.opacity(0.7))
                        }
                    }
                }
            }
            .frame(height: 68)

            HStack(spacing: 4) {
                Text("- - -")
                    .font(.caption2.weight(.bold))
                Text("meta \(formatVolume(store.goalMl))")
                    .font(.caption2)
            }
            .foregroundColor(.white.opacity(0.7))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Consumo dos últimos 7 dias")
        .accessibilityValue(days.map { "\($0.label): \($0.ml) mililitros" }.joined(separator: ", "))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(Palette.brightBlue)
            Text("Seu histórico aparece aqui conforme você registra água.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 8)
    }
}
