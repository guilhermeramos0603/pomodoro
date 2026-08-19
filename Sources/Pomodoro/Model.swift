import AppKit
import SwiftUI

/// One step of a pomodoro sequence.
enum BlockKind: String, Codable, CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var label: String {
        switch self {
        case .focus:      return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak:  return "Long break"
        }
    }

    var shortLabel: String {
        switch self {
        case .focus:      return "F"
        case .shortBreak: return "S"
        case .longBreak:  return "L"
        }
    }

    /// Monochrome on purpose: phases read as brightness tiers, not as hues.
    var color: Color {
        switch self {
        case .focus:      return Color.white.opacity(0.92)
        case .shortBreak: return Color.white.opacity(0.38)
        case .longBreak:  return Color.white.opacity(0.62)
        }
    }

    var isBreak: Bool { self != .focus }
}

struct Block: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: BlockKind
    var minutes: Int

    var duration: TimeInterval { TimeInterval(max(1, minutes) * 60) }
}

enum SequenceMode: String, Codable, CaseIterable, Identifiable {
    case classic
    case custom

    var id: String { rawValue }
    var label: String { self == .classic ? "Classic" : "Custom" }
}

/// Every user preference, in one Codable value so persistence is a single blob.
struct SettingsData: Codable, Equatable {
    // Timer
    var mode: SequenceMode = .classic
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var roundsBeforeLongBreak: Int = 4
    var customBlocks: [Block] = [
        Block(kind: .focus, minutes: 25),
        Block(kind: .shortBreak, minutes: 5),
        Block(kind: .focus, minutes: 25),
        Block(kind: .longBreak, minutes: 15)
    ]

    // Behaviour
    var autoStartBreaks: Bool = true
    var autoStartFocus: Bool = false
    var soundEnabled: Bool = true
    var soundName: String = "Glass"

    // Appearance
    var tintOpacity: Double = 0.55      // how black the panel is, 0...1
    var blurLevel: Int = 2              // 0 = no blur, 1...5 = system materials
    var windowOpacity: Double = 1.0     // whole-window alpha, 0.2...1
    var allSpaces: Bool = true          // show on every Space and over full-screen apps

    // Geometry — the window and the content are sized independently.
    var windowWidth: Double = 250
    var windowHeight: Double = 172
    var contentScale: Double = 1.0      // size of the timer itself, 0.5...3
    var windowOrigin: [Double]? = nil   // nil = place it on first launch

    /// The sequence the engine actually runs.
    var blocks: [Block] {
        switch mode {
        case .custom:
            return customBlocks.isEmpty ? [Block(kind: .focus, minutes: focusMinutes)] : customBlocks
        case .classic:
            let rounds = max(1, roundsBeforeLongBreak)
            var out: [Block] = []
            for round in 1...rounds {
                out.append(Block(kind: .focus, minutes: focusMinutes))
                out.append(round == rounds
                           ? Block(kind: .longBreak, minutes: longBreakMinutes)
                           : Block(kind: .shortBreak, minutes: shortBreakMinutes))
            }
            return out
        }
    }
}

extension SettingsData {
    enum CodingKeys: String, CodingKey {
        case mode, focusMinutes, shortBreakMinutes, longBreakMinutes, roundsBeforeLongBreak
        case customBlocks, autoStartBreaks, autoStartFocus, soundEnabled, soundName
        case tintOpacity, blurLevel, windowOpacity, allSpaces
        case windowWidth, windowHeight, contentScale, windowOrigin
    }

    /// Lenient on purpose: a preferences file written by an older build is missing the keys
    /// added since, and a strict decode would throw away every setting the user has.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = SettingsData()
        d.mode = try c.decodeIfPresent(SequenceMode.self, forKey: .mode) ?? d.mode
        d.focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
        d.shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? d.shortBreakMinutes
        d.longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes
        d.roundsBeforeLongBreak = try c.decodeIfPresent(Int.self, forKey: .roundsBeforeLongBreak) ?? d.roundsBeforeLongBreak
        d.customBlocks = try c.decodeIfPresent([Block].self, forKey: .customBlocks) ?? d.customBlocks
        d.autoStartBreaks = try c.decodeIfPresent(Bool.self, forKey: .autoStartBreaks) ?? d.autoStartBreaks
        d.autoStartFocus = try c.decodeIfPresent(Bool.self, forKey: .autoStartFocus) ?? d.autoStartFocus
        d.soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        d.soundName = try c.decodeIfPresent(String.self, forKey: .soundName) ?? d.soundName
        d.tintOpacity = try c.decodeIfPresent(Double.self, forKey: .tintOpacity) ?? d.tintOpacity
        d.blurLevel = try c.decodeIfPresent(Int.self, forKey: .blurLevel) ?? d.blurLevel
        d.windowOpacity = try c.decodeIfPresent(Double.self, forKey: .windowOpacity) ?? d.windowOpacity
        d.allSpaces = try c.decodeIfPresent(Bool.self, forKey: .allSpaces) ?? d.allSpaces
        d.windowWidth = try c.decodeIfPresent(Double.self, forKey: .windowWidth) ?? d.windowWidth
        d.windowHeight = try c.decodeIfPresent(Double.self, forKey: .windowHeight) ?? d.windowHeight
        d.contentScale = try c.decodeIfPresent(Double.self, forKey: .contentScale) ?? d.contentScale
        d.windowOrigin = try c.decodeIfPresent([Double].self, forKey: .windowOrigin) ?? d.windowOrigin
        self = d
    }
}

let blurLevelNames = ["Off", "Subtle", "Light", "Medium", "Strong", "Solid"]

func blurMaterial(for level: Int) -> NSVisualEffectView.Material {
    switch level {
    case 1:  return .hudWindow
    case 2:  return .popover
    case 3:  return .menu
    case 4:  return .sidebar
    default: return .underWindowBackground
    }
}

let systemSoundNames = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
                        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
