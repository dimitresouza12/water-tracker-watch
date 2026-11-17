import HealthKit
import os

/// Conversa com o app Saúde. Só mexe em água (`dietaryWater`).
final class HealthKitService {
    private let store = HKHealthStore()
    private let waterType = HKQuantityType(.dietaryWater)
    private let log = Logger(subsystem: "com.dimitre.WaterTracker", category: "HealthKit")

    private var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [waterType], read: [waterType])
        } catch {
            log.error("Pedido de permissão falhou: \(error.localizedDescription)")
        }
    }

    func saveWater(ml: Int) async {
        guard isAvailable else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml))
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())
        do {
            try await store.save(sample)
        } catch {
            log.error("Não consegui salvar \(ml) ml no Saúde: \(error.localizedDescription)")
        }
    }
}
