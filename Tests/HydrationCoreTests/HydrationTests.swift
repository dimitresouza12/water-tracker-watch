import XCTest
@testable import HydrationCore

final class HydrationTests: XCTestCase {
    /// Calendário fixo (UTC) para o resultado não depender do fuso de quem roda o teste.
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 16 de novembro de 2026, meio-dia.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12))!
    }

    // MARK: meta sugerida

    func testMetaSugeridaArredondaPara250ml() {
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 70), 2500)  // 2450 ml
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 60), 2000)  // 2100 ml
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 80), 2750)  // 2800 ml
    }

    func testMetaSugeridaRespeitaMinimoEMaximo() {
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 10), 500)
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 300), 6000)
    }

    // MARK: progresso

    func testProgressoNaoPassaDeUm() {
        XCTAssertEqual(Hydration.progress(totalMl: 1000, goalMl: 2000), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Hydration.progress(totalMl: 3000, goalMl: 2000), 1.0, accuracy: 0.0001)
    }

    func testProgressoComMetaZeroNaoQuebra() {
        XCTAssertEqual(Hydration.progress(totalMl: 500, goalMl: 0), 0)
    }

    // MARK: chave do dia

    func testChaveDoDia() {
        XCTAssertEqual(Hydration.dayKey(for: now, calendar: calendar), "2026-11-16")
        let primeiro = calendar.date(from: DateComponents(year: 2027, month: 1, day: 5))!
        XCTAssertEqual(Hydration.dayKey(for: primeiro, calendar: calendar), "2027-01-05")
    }

    // MARK: últimos 7 dias

    func testUltimos7DiasVemEmOrdemEHojeUsaOTotalAtual() {
        let history = ["2026-11-15": 1800, "2026-11-14": 2200, "2026-11-10": 900]
        let days = Hydration.last7Days(history: history, todayMl: 1250, now: now, calendar: calendar)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.map(\.ml), [900, 0, 0, 0, 2200, 1800, 1250])
        XCTAssertEqual(days.filter(\.isToday).count, 1)
        XCTAssertTrue(days.last!.isToday)
    }

    func testRotuloDoDiaEUmaLetraMaiuscula() {
        let days = Hydration.last7Days(history: [:], todayMl: 0, now: now, calendar: calendar)
        // 16/11/2026 é segunda-feira
        XCTAssertEqual(days.last!.label, "S")
        XCTAssertTrue(days.allSatisfy { $0.label.count == 1 && $0.label == $0.label.uppercased() })
    }

    // MARK: sequência

    func testSequenciaContaHojeQuandoJaBateuAMeta() {
        let history = ["2026-11-15": 2000, "2026-11-14": 2500]
        let streak = Hydration.currentStreak(history: history, todayMl: 2000, goalMl: 2000, now: now, calendar: calendar)
        XCTAssertEqual(streak, 3)
    }

    func testSequenciaDeOntemContinuaVivaMesmoSemBaterHoje() {
        let history = ["2026-11-15": 2000, "2026-11-14": 2500]
        let streak = Hydration.currentStreak(history: history, todayMl: 300, goalMl: 2000, now: now, calendar: calendar)
        XCTAssertEqual(streak, 2)
    }

    func testSequenciaQuebraNoPrimeiroDiaAbaixoDaMeta() {
        let history = ["2026-11-15": 2000, "2026-11-14": 1500, "2026-11-13": 2500]
        let streak = Hydration.currentStreak(history: history, todayMl: 2000, goalMl: 2000, now: now, calendar: calendar)
        XCTAssertEqual(streak, 2)
    }

    func testSemHistoricoENadaHojeNaoTemSequencia() {
        let streak = Hydration.currentStreak(history: [:], todayMl: 0, goalMl: 2000, now: now, calendar: calendar)
        XCTAssertEqual(streak, 0)
    }

    // MARK: média

    func testMediaIgnoraDiasSemRegistro() {
        let days = [DayRecord(label: "S", ml: 0, isToday: false),
                    DayRecord(label: "T", ml: 1000, isToday: false),
                    DayRecord(label: "Q", ml: 2000, isToday: true)]
        XCTAssertEqual(Hydration.weekAverageMl(of: days), 1500)
    }

    func testMediaSemNenhumRegistroEZero() {
        let days = [DayRecord(label: "S", ml: 0, isToday: true)]
        XCTAssertEqual(Hydration.weekAverageMl(of: days), 0)
    }
}
