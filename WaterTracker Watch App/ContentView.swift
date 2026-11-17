import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MainView()
            HistoryView()
            SettingsView()
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }
}

struct MainView: View {
    @EnvironmentObject var store: WaterStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showPicker = false
    @State private var splash = 0
    @State private var celebrate = false

    /// Azul fixo para tudo que é água; só o contorno do corpo (e o selo de meta) muda com o progresso.
    private let accent = Palette.cyan
    private var status: Color { Palette.hydration(store.progress) }
    private var remainingMl: Int { max(0, store.goalMl - store.totalMl) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                HydrationBody(progress: store.progress, color: accent,
                              outlineColor: status,
                              reduceMotion: reduceMotion, splash: splash, glow: celebrate,
                              powered: store.isGoalReached)
                    .frame(maxHeight: .infinity)
                summary
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Água de hoje")
            .accessibilityValue("\(store.totalMl) mililitros de \(store.goalMl), \(Int(store.progress * 100)) por cento da meta")

            actionRow
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .sheet(isPresented: $showPicker) {
            AmountPicker()
        }
        .onChange(of: store.isGoalReached) { _, reached in
            guard reached else { return }
            celebrate = true
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                celebrate = false
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            if store.isGoalReached {
                HStack(spacing: 4) {
                    Text("Meta batida")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "hand.thumbsup.fill")
                        .symbolEffect(.bounce, value: celebrate)
                }
                .font(.caption2.weight(.semibold))
                .foregroundColor(status)
                .transition(.scale.combined(with: .opacity))
            }
            Text(formatVolume(store.totalMl))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text("de \(formatVolume(store.goalMl))")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            if !store.isGoalReached {
                Text("Faltam \(formatVolume(remainingMl))")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 4)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.totalMl)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.isGoalReached)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button { showPicker = true } label: {
                Image(systemName: "waterbottle.fill")
                    .font(.system(.body))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Escolher quantidade")

            Button {
                splash += 1
                store.add(ml: store.lastAmountMl)
            } label: {
                Text("+ \(formatVolume(store.lastAmountMl))")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(Palette.navy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Adicionar \(store.lastAmountMl) mililitros")
            .accessibilityHint("Use o botão ao lado para mudar a quantidade")
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    ContentView()
        .environmentObject(WaterStore())
}
