// swift-tools-version:5.9
import PackageDescription

// Pacote só para rodar os testes da lógica com `swift test`, sem simulador.
// Ele aponta para o mesmo arquivo que o app compila, então não existe cópia do código.
let package = Package(
    name: "HydrationCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "HydrationCore",
            path: "WaterTracker Watch App",
            exclude: [
                "Assets.xcassets",
                "BodyView.swift", "ContentView.swift", "AmountPicker.swift", "HistoryView.swift",
                "SettingsView.swift", "Theme.swift", "WaterStore.swift", "WaterTrackerApp.swift",
                "HealthKitService.swift", "ReminderScheduler.swift",
                "WaterTracker Watch App.entitlements"
            ],
            sources: ["HydrationLogic.swift"]
        ),
        .testTarget(
            name: "HydrationCoreTests",
            dependencies: ["HydrationCore"],
            path: "Tests/HydrationCoreTests"
        )
    ]
)
