import SwiftUI

/// Superfície da água: `level` de 0 a 1 (de baixo para cima), `phase` desloca a onda.
struct WaveShape: Shape {
    var level: Double
    var phase: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, phase) }
        set { level = newValue.first; phase = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard level > 0 else { return path }

        let top = rect.height * (1 - level)
        let amplitude: CGFloat = level >= 0.995 ? 0 : 2
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        var x: CGFloat = 0
        while x <= rect.width {
            let y = top + amplitude * sin(x / rect.width * 3 * .pi + phase)
            path.addLine(to: CGPoint(x: rect.minX + x, y: y))
            x += 2
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Figura humana translúcida que se enche de água conforme o progresso do dia.
/// `splash` muda a cada registro e dispara a gota; `glow` intensifica o brilho (meta batida).
struct HydrationBody: View {
    let progress: Double
    let color: Color
    let outlineColor: Color
    let reduceMotion: Bool
    var splash: Int = 0
    var glow: Bool = false
    /// Meta batida: aura que pulsa em volta do corpo.
    var powered: Bool = false

    @State private var shown: Double = 0
    @State private var dropY: CGFloat = -30
    @State private var dropOpacity: Double = 0
    @State private var pulse = false

    private var figure: some View {
        Image(systemName: "figure.stand")
            .resizable()
            .scaledToFit()
    }

    /// Anel de ~1pt ao redor da figura: cópias deslocadas, com o miolo recortado para manter a transparência.
    private var outline: some View {
        let d: CGFloat = 1.2, e: CGFloat = 0.85
        let offsets = [CGSize(width: d, height: 0), CGSize(width: -d, height: 0),
                       CGSize(width: 0, height: d), CGSize(width: 0, height: -d),
                       CGSize(width: e, height: e), CGSize(width: -e, height: e),
                       CGSize(width: e, height: -e), CGSize(width: -e, height: -e)]
        return ZStack {
            ForEach(offsets.indices, id: \.self) { i in
                figure.foregroundStyle(outlineColor).offset(offsets[i])
            }
            figure.blendMode(.destinationOut)
        }
        .compositingGroup()
        .shadow(color: outlineColor.opacity(glow || powered ? 1 : 0.8),
                radius: glow ? 9 : (powered ? (pulse ? 13 : 5) : 3))
        .animation(.easeInOut(duration: 0.5), value: glow)
    }

    var body: some View {
        figure
            .foregroundStyle(.white.opacity(0.2))
            .overlay { outline }
            .overlay {
                // A onda só precisa de quadros quando há uma superfície visível (corpo nem vazio nem cheio).
                TimelineView(.animation(minimumInterval: 1.0 / 12,
                                        paused: reduceMotion || shown <= 0 || shown >= 0.995)) { context in
                    WaveShape(level: shown,
                              phase: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 2)
                        .fill(LinearGradient(colors: [color, color.opacity(0.6)],
                                             startPoint: .top, endPoint: .bottom))
                }
                .mask { figure }
            }
            .overlay(alignment: .top) {
                Image(systemName: "drop.fill")
                    .font(.footnote)
                    .foregroundStyle(color)
                    .offset(y: dropY)
                    .opacity(dropOpacity)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: outlineColor)
            .onAppear { shown = progress }
            .onChange(of: progress) { old, new in
                // A água sobe um instante depois da gota, para o gesto fazer sentido.
                let spring = Animation.spring(response: 0.7, dampingFraction: 0.75)
                withAnimation(reduceMotion ? nil : (new > old ? spring.delay(0.25) : spring)) {
                    shown = new
                }
            }
            .onChange(of: splash) { _, _ in dropIn() }
            .scaleEffect(powered && pulse ? 1.05 : 1)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: powered)
            .onAppear { updatePulse() }
            .onChange(of: powered) { _, _ in updatePulse() }
            .accessibilityHidden(true)
    }

    /// Pulso contínuo só enquanto a meta está batida (e sem "Reduzir movimento").
    private func updatePulse() {
        if powered && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        } else {
            withAnimation(.easeOut(duration: 0.3)) { pulse = false }
        }
    }

    private func dropIn() {
        guard !reduceMotion else { return }
        dropY = -26
        dropOpacity = 1
        withAnimation(.easeIn(duration: 0.28)) { dropY = 34 }
        withAnimation(.easeOut(duration: 0.12).delay(0.26)) { dropOpacity = 0 }
    }
}
