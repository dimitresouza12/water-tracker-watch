import SwiftUI

enum Palette {
    static let cyan = Color(red: 0.28, green: 0.79, blue: 0.89)
    static let brightBlue = Color(red: 0.22, green: 0.62, blue: 1.0)
    static let mint = Color(red: 0.45, green: 0.92, blue: 0.70)
    static let navy = Color(red: 0.04, green: 0.10, blue: 0.15)
    static let flame = Color(red: 1.0, green: 0.62, blue: 0.25)
}

/// 850 -> "850 ml", 1200 -> "1,2 L", 1250 -> "1,25 L" (vírgula, como no Brasil).
func formatVolume(_ ml: Int) -> String {
    guard ml >= 1000 else { return "\(ml) ml" }
    let digits = ml % 100 == 0 ? 1 : 2
    let liters = String(format: "%.\(digits)f", locale: Locale(identifier: "pt_BR"), Double(ml) / 1000)
    return "\(liters) L"
}

/// Feedback de toque que não altera o layout.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private typealias RGB = (r: Double, g: Double, b: Double)

private func mix(_ a: RGB, _ b: RGB, _ t: Double) -> Color {
    Color(red: a.r + (b.r - a.r) * t, green: a.g + (b.g - a.g) * t, blue: a.b + (b.b - a.b) * t)
}

extension Palette {
    /// Cor da hidratação: coral (muita água a beber) → âmbar → ciano → verde-água (meta batida).
    static func hydration(_ progress: Double) -> Color {
        let stops: [(at: Double, rgb: RGB)] = [
            (0.0, (1.0, 0.40, 0.38)),
            (0.35, (1.0, 0.70, 0.25)),
            (0.65, (0.28, 0.79, 0.89)),
            (1.0, (0.45, 0.92, 0.70))
        ]
        let p = min(max(progress, 0), 1)
        guard let i = stops.indices.dropFirst().first(where: { p <= stops[$0].at }) else { return mix(stops[3].rgb, stops[3].rgb, 0) }
        let (a, b) = (stops[i - 1], stops[i])
        return mix(a.rgb, b.rgb, (p - a.at) / (b.at - a.at))
    }
}

/// Fundo que esquenta do azul-marinho para um azul profundo conforme o dia avança; verde-água na meta.
struct AppBackground: View {
    let progress: Double
    let reached: Bool

    var body: some View {
        LinearGradient(
            colors: reached
                ? [Color(red: 0.02, green: 0.22, blue: 0.22), Color(red: 0.03, green: 0.13, blue: 0.17)]
                : [mix((0.05, 0.09, 0.14), (0.03, 0.20, 0.36), progress),
                   mix((0.10, 0.14, 0.22), (0.03, 0.30, 0.48), progress)],
            startPoint: .top, endPoint: .bottom
        )
        .animation(.easeInOut(duration: 0.8), value: progress)
        .animation(.easeInOut(duration: 0.8), value: reached)
    }
}

private struct AppBackgroundModifier: ViewModifier {
    @EnvironmentObject var store: WaterStore

    func body(content: Content) -> some View {
        content.containerBackground(for: .tabView) {
            AppBackground(progress: store.progress, reached: store.isGoalReached)
        }
    }
}

extension View {
    /// Fundo padrão das páginas do app, ligado ao progresso do dia.
    func appBackground() -> some View { modifier(AppBackgroundModifier()) }
}
