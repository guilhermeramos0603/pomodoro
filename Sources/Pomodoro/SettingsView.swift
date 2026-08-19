import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            TimerTab(settings: settings)
                .tabItem { Label("Timer", systemImage: "timer") }
            AppearanceTab(settings: settings)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            BehaviorTab(settings: settings)
                .tabItem { Label("Behaviour", systemImage: "slider.horizontal.3") }
        }
        .padding(14)
        .frame(width: 470, height: 430)
    }
}

// MARK: - Timer

private struct TimerTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $settings.data.mode) {
                ForEach(SequenceMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if settings.data.mode == .classic {
                classic
            } else {
                custom
            }

            Spacer(minLength: 0)
            sequencePreview
        }
        .padding(.top, 12)
    }

    private var classic: some View {
        VStack(alignment: .leading, spacing: 10) {
            MinutesRow(title: "Focus", value: $settings.data.focusMinutes, range: 1...240)
            MinutesRow(title: "Short break", value: $settings.data.shortBreakMinutes, range: 1...120)
            MinutesRow(title: "Long break", value: $settings.data.longBreakMinutes, range: 1...120)

            Divider().padding(.vertical, 2)

            HStack {
                Text("Long break after")
                Spacer()
                Stepper(value: $settings.data.roundsBeforeLongBreak, in: 1...12) {
                    Text("\(settings.data.roundsBeforeLongBreak) rounds")
                        .monospacedDigit()
                        .frame(width: 74, alignment: .trailing)
                }
            }
        }
    }

    private var custom: some View {
        VStack(alignment: .leading, spacing: 8) {
            List {
                ForEach($settings.data.customBlocks) { $block in
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary.opacity(0.5))
                            .font(.system(size: 10))

                        Picker("", selection: $block.kind) {
                            ForEach(BlockKind.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 130)

                        Stepper(value: $block.minutes, in: 1...240) {
                            Text("\(block.minutes) min")
                                .monospacedDigit()
                                .frame(width: 60, alignment: .trailing)
                        }

                        Spacer()

                        Button {
                            settings.data.customBlocks.removeAll { $0.id == block.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(settings.data.customBlocks.count <= 1)
                    }
                    .padding(.vertical, 2)
                }
                .onMove { from, to in settings.data.customBlocks.move(fromOffsets: from, toOffset: to) }
            }
            .frame(minHeight: 190)

            HStack {
                Menu("Add block") {
                    ForEach(BlockKind.allCases) { kind in
                        Button(kind.label) {
                            let minutes: Int
                            switch kind {
                            case .focus:      minutes = settings.data.focusMinutes
                            case .shortBreak: minutes = settings.data.shortBreakMinutes
                            case .longBreak:  minutes = settings.data.longBreakMinutes
                            }
                            settings.data.customBlocks.append(Block(kind: kind, minutes: minutes))
                        }
                    }
                }
                .frame(width: 120)

                Button("Copy from Classic") { settings.copyClassicIntoCustom() }

                Spacer()
                Text("Drag to reorder. The list loops.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var sequencePreview: some View {
        let blocks = settings.data.blocks
        let total = blocks.reduce(0) { $0 + $1.minutes }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Sequence")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 3) {
                ForEach(blocks) { block in
                    Text(block.kind.shortLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(block.kind == .focus ? 0.95 : 0.55))
                        .frame(width: 17, height: 17)
                        .background(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
                                .background(Circle().fill(Color.primary.opacity(block.kind == .focus ? 0.14 : 0.05)))
                        )
                }
                Text("↻  \(total) min total")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
}

private struct MinutesRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: $value, in: range) {
                Text("\(value) min")
                    .monospacedDigit()
                    .frame(width: 74, alignment: .trailing)
            }
        }
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Black opacity")
                    Spacer()
                    Text("\(Int(settings.data.tintOpacity * 100))%")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.data.tintOpacity, in: 0...1)
                Text("How dark the panel is over whatever is behind it.")
                    .font(.caption).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Blur")
                    Spacer()
                    Text(blurLevelNames[min(settings.data.blurLevel, blurLevelNames.count - 1)])
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.data.blurLevel) },
                        set: { settings.data.blurLevel = Int($0.rounded()) }
                    ),
                    in: 0...5, step: 1
                )
                Text("Off shows the desktop through the tint with no blur; higher steps use denser system materials.")
                    .font(.caption).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Window opacity")
                    Spacer()
                    Text("\(Int(settings.data.windowOpacity * 100))%")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.data.windowOpacity, in: 0.2...1)
                Text("Fades the whole panel, text included.")
                    .font(.caption).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(settings.data.windowWidth)) pt wide")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.data.windowWidth,
                       in: Double(AppSettings.minWidth)...Double(AppSettings.maxWidth))
                Text("You can also drag the grip in the panel's bottom-right corner, or any of its edges.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Toggle("Show on all Spaces and above full-screen apps", isOn: $settings.data.allSpaces)

            Spacer()
        }
        .padding(.top, 14)
    }
}

// MARK: - Behaviour

private struct BehaviorTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Start breaks automatically", isOn: $settings.data.autoStartBreaks)
            Toggle("Start the next focus block automatically", isOn: $settings.data.autoStartFocus)

            Divider()

            Toggle("Play a sound when a block ends", isOn: $settings.data.soundEnabled)

            HStack {
                Picker("Sound", selection: $settings.data.soundName) {
                    ForEach(systemSoundNames, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 230)
                .disabled(!settings.data.soundEnabled)

                Button("Test") { NSSound(named: settings.data.soundName)?.play() }
                    .disabled(!settings.data.soundEnabled)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Reset all settings") { settings.resetToDefaults() }
            }
        }
        .padding(.top, 14)
    }
}
