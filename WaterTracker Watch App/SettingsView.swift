import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: WaterStore
    @State private var showGoal = false
    @State private var showWeight = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Ajustes")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)

                goalCard
                weightCard
                remindersCard
                healthNote
            }
            .padding(.horizontal, 6)
        }
        .sheet(isPresented: $showGoal) { GoalSheet() }
        .sheet(isPresented: $showWeight) { WeightSheet() }
        .appBackground()
    }

    // MARK: Meta

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showGoal = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        IconBadge(systemName: "drop.fill", color: Palette.cyan)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Meta diária")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(formatVolume(store.goalMl))
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundColor(Palette.cyan)
                                .contentTransition(.numericText())
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Text("≈ \(cupsForGoal) copos de \(formatVolume(store.lastAmountMl))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Meta diária, \(formatVolume(store.goalMl))")
            .accessibilityHint("Toque para alterar a meta")

            if store.suggestedGoalMl != store.goalMl {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        store.goalMl = store.suggestedGoalMl
                    }
                } label: {
                    Label("Sugerida \(formatVolume(store.suggestedGoalMl))", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Palette.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Palette.cyan)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressStyle())
                .accessibilityHint("Calculada com 35 mililitros por quilo")
            }
        }
        .settingsCard()
    }

    private var cupsForGoal: Int {
        Int((Double(store.goalMl) / Double(max(store.lastAmountMl, 1))).rounded(.up))
    }

    // MARK: Peso

    private var weightCard: some View {
        Button { showWeight = true } label: {
            HStack(spacing: 8) {
                IconBadge(systemName: "figure.stand", color: Palette.brightBlue)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Peso")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(store.weightKg) kg")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .settingsCard()
        .accessibilityLabel("Peso, \(store.weightKg) quilos")
        .accessibilityHint("Abre a lista de pesos")
    }

    // MARK: Lembretes

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                IconBadge(systemName: store.notificationsEnabled ? "bell.fill" : "bell.slash.fill",
                          color: store.notificationsEnabled ? Palette.flame : .gray)
                Text("Lembretes")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }

            HStack {
                Text(store.notificationsEnabled ? "\(reminderHours.count) por dia" : "Desligados")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Toggle("Lembretes", isOn: $store.notificationsEnabled.animation(.spring(response: 0.4, dampingFraction: 0.85)))
                    .labelsHidden()
                    .tint(Palette.cyan)
                    .fixedSize()
            }

            if store.notificationsEnabled {
                ReminderTimeline(hours: reminderHours,
                                 start: store.reminderStartHour,
                                 end: store.reminderEndHour)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                VStack(spacing: 6) {
                    ValueStepper(title: "A cada",value: "\(store.reminderIntervalHours) h",
                                 canDecrement: store.reminderIntervalHours > 1,
                                 canIncrement: store.reminderIntervalHours < 4,
                                 decrement: { store.reminderIntervalHours -= 1 },
                                 increment: { store.reminderIntervalHours += 1 })
                    ValueStepper(title: "Início", value: "\(store.reminderStartHour)h",
                                 canDecrement: store.reminderStartHour > 5,
                                 canIncrement: store.reminderStartHour < 12,
                                 decrement: { store.reminderStartHour -= 1 },
                                 increment: { store.reminderStartHour += 1 })
                    ValueStepper(title: "Fim", value: "\(store.reminderEndHour)h",
                                 canDecrement: store.reminderEndHour > 16,
                                 canIncrement: store.reminderEndHour < 23,
                                 decrement: { store.reminderEndHour -= 1 },
                                 increment: { store.reminderEndHour += 1 })
                }
                .transition(.opacity)
            }
        }
        .settingsCard()
    }

    private var reminderHours: [Int] {
        Array(stride(from: store.reminderStartHour,
                     through: max(store.reminderEndHour, store.reminderStartHour),
                     by: store.reminderIntervalHours))
    }

    private var healthNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.pink)
            Text("Cada registro também vai para o app Saúde.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}

// MARK: - Componentes

/// Ícone em círculo colorido que identifica cada seção.
private struct IconBadge: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 26, height: 26)
            .background(color.gradient)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

/// Valor com botões de − e + no estilo do app (alvos de 38pt).
private struct ValueStepper: View {
    let title: String
    let value: String
    let canDecrement: Bool
    let canIncrement: Bool
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                if !title.isEmpty {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(value)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            stepButton("minus", enabled: canDecrement, action: decrement, label: "Diminuir \(title.isEmpty ? value : title)")
            stepButton("plus", enabled: canIncrement, action: increment, label: "Aumentar \(title.isEmpty ? value : title)")
        }
        .accessibilityElement(children: .contain)
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void, label: String) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}

/// Linha do dia com um ponto por lembrete, entre o horário de início e o de fim.
private struct ReminderTimeline: View {
    let hours: [Int]
    let start: Int
    let end: Int

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let span = Double(max(end - start, 1))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 3)
                    ForEach(hours, id: \.self) { hour in
                        Circle()
                            .fill(Palette.flame)
                            .frame(width: 7, height: 7)
                            .offset(x: CGFloat(Double(hour - start) / span) * (geo.size.width - 7))
                    }
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 9)

            HStack {
                Text("\(start)h")
                Spacer()
                Text("\(end)h")
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.6))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lembretes às " + hours.map { "\($0) horas" }.joined(separator: ", "))
    }
}

private extension View {
    func settingsCard() -> some View {
        padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Peso

/// Lista com todos os pesos (30 a 200 kg): rola com o dedo ou com a Digital Crown, e um toque escolhe.
struct WeightSheet: View {
    @EnvironmentObject var store: WaterStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    Text("Seu peso")
                        .font(.headline)
                        .padding(.bottom, 2)

                    ForEach(30...200, id: \.self) { kg in
                        let selected = store.weightKg == kg
                        Button {
                            store.weightKg = kg
                            dismiss()
                        } label: {
                            Text("\(kg) kg")
                                .font(.system(.title3, design: .rounded).weight(selected ? .bold : .medium))
                                .foregroundColor(selected ? Palette.navy : .white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(selected ? Palette.cyan : Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PressStyle())
                        .id(kg)
                        .accessibilityLabel("\(kg) quilos")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 6)
            }
            .onAppear { proxy.scrollTo(store.weightKg, anchor: .center) }
        }
    }
}

// MARK: - Meta

/// Lista com todas as metas (500 ml a 6 L): rola com o dedo ou com a Digital Crown, e um toque escolhe.
struct GoalSheet: View {
    @EnvironmentObject var store: WaterStore
    @Environment(\.dismiss) private var dismiss

    private let options = Array(stride(from: 500, through: 6000, by: 250))

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    Text("Meta diária")
                        .font(.headline)
                        .padding(.bottom, 2)

                    ForEach(options, id: \.self) { ml in
                        let selected = store.goalMl == ml
                        let suggested = store.suggestedGoalMl == ml
                        Button {
                            store.goalMl = ml
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                if suggested {
                                    Image(systemName: "sparkles")
                                        .font(.footnote)
                                }
                                Text(formatVolume(ml))
                                    .font(.system(.title3, design: .rounded).weight(selected ? .bold : .medium))
                            }
                            .foregroundColor(selected ? Palette.navy : .white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected ? Palette.cyan : Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PressStyle())
                        .id(ml)
                        .accessibilityLabel(formatVolume(ml) + (suggested ? ", sugerida" : ""))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }

                    Label("Sugerida pelo seu peso", systemImage: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 2)
                }
                .padding(.horizontal, 6)
            }
            .onAppear { proxy.scrollTo(store.goalMl, anchor: .center) }
        }
    }
}
