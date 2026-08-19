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

    var color: Color {
        switch self {
        case .focus:      return Color(red: 1.00, green: 0.42, blue: 0.35)
        case .shortBreak: return Color(red: 0.35, green: 0.82, blue: 0.60)
        case .longBreak:  return Color(red: 0.40, green: 0.65, blue: 1.00)
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
    var windowOpacity: Double = 1.0     // whole-window alpha, 0.3...1
    var allSpaces: Bool = true          // show on every Space and over full-screen apps

    // Window position (nil = place it on first launch)
    var windowOrigin: [Double]? = nil

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
