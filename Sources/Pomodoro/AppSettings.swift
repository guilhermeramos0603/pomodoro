import AppKit
import Combine

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

    /// The size the timer content is drawn at when `contentScale` is 1.
    static let baseSize = CGSize(width: 250, height: 172)
    /// Smallest window that still fits the content legibly.
    static let minSize = CGSize(width: 170, height: 120)
    static let minContentScale = 0.5
    static let maxContentScale = 3.0

    /// The window can grow to the whole visible screen; the content does not follow it.
    var panelSize: CGSize {
        let limit = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size
            ?? CGSize(width: 1440, height: 900)
        return CGSize(
            width: min(limit.width, max(Self.minSize.width, CGFloat(data.windowWidth))).rounded(),
            height: min(limit.height, max(Self.minSize.height, CGFloat(data.windowHeight))).rounded()
        )
    }

    /// Fills the custom sequence with what the classic settings would generate.
    func copyClassicIntoCustom() {
        var classic = data
        classic.mode = .classic
        data.customBlocks = classic.blocks
    }
}
