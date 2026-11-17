import SwiftUI

struct AmountPreset: Identifiable {
    let ml: Int
    let name: String
    var id: Int { ml }

    static let all = [
        AmountPreset(ml: 100, name: "Gole"),
        AmountPreset(ml: 150, name: "Xícara"),
        AmountPreset(ml: 200, name: "Copo"),
        AmountPreset(ml: 250, name: "Copo G"),
        AmountPreset(ml: 300, name: "Caneca"),
        AmountPreset(ml: 400, name: "Copo XL"),
        AmountPreset(ml: 500, name: "Garrafa"),
        AmountPreset(ml: 750, name: "Garrafa G"),
        AmountPreset(ml: 1000, name: "Litro"),
        AmountPreset(ml: 1500, name: "Garrafa XL"),
        AmountPreset(ml: 2000, name: "Garrafão")
    ]
}

/// Folha para escolher a quantidade do próximo registro.
struct AmountPicker: View {
    @EnvironmentObject var store: WaterStore
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Quantidade")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(AmountPreset.all) { preset in
                        let selected = store.lastAmountMl == preset.ml
                        Button {
                            store.lastAmountMl = preset.ml
                            dismiss()
                        } label: {
                            VStack(spacing: 0) {
                                Text(formatVolume(preset.ml))
                                    .font(.system(.callout, design: .rounded).weight(.semibold))
                                Text(preset.name)
                                    .font(.caption2)
                            }
                            .foregroundColor(selected ? Palette.navy : .white)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(selected ? Palette.cyan : Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel("\(preset.ml) mililitros, \(preset.name)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }

                Button {
                    store.remove(ml: store.lastAmountMl)
                    dismiss()
                } label: {
                    Label("Remover \(formatVolume(store.lastAmountMl))", systemImage: "minus.circle")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressStyle())
                .disabled(store.totalMl == 0)
                .opacity(store.totalMl == 0 ? 0.4 : 1)
            }
        }
    }
}
