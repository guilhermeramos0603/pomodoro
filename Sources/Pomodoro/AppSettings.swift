import Combine
import Foundation

/// Observable wrapper around `SettingsData`, persisted to UserDefaults on every change.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private static let key = "settings.v1"

    @Published var data: SettingsData

    private var bag = Set<AnyCancellable>()

    private init() {
        if let raw = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: raw) {
            data = decoded
        } else {
            data = SettingsData()
        }

        $data
            .dropFirst()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { value in
                guard let raw = try? JSONEncoder().encode(value) else { return }
                UserDefaults.standard.set(raw, forKey: Self.key)
            }
            .store(in: &bag)
    }

    func resetToDefaults() {
        let origin = data.windowOrigin
        var fresh = SettingsData()
        fresh.windowOrigin = origin
        data = fresh
    }

    /// Fills the custom sequence with what the classic settings would generate.
    func copyClassicIntoCustom() {
        var classic = data
        classic.mode = .classic
        data.customBlocks = classic.blocks
    }
}
