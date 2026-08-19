import SwiftUI

struct TimerView: View {
    @ObservedObject var engine: PomodoroEngine
    @ObservedObject var settings: AppSettings

    var onSettings: () -> Void
    var onHide: () -> Void
    var onQuit: () -> Void

    private var kind: BlockKind { engine.currentBlock.kind }

    var body: some View {
        ZStack {
            Color.black.opacity(settings.data.tintOpacity)

            VStack(spacing: 8) {
                header
                time
                progressBar
                sequenceStrip
                controls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu {
            Button("Settings…", action: onSettings)
            Button("Hide Timer", action: onHide)
            Divider()
            Button("Quit Pomodoro", action: onQuit)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(kind.color)
                .frame(width: 6, height: 6)
                .opacity(engine.isRunning ? 1 : 0.45)

            Text(kind.label.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.72))

            Spacer(minLength: 4)

            Text("\(engine.index + 1)/\(max(engine.blocks.count, 1))")
                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.35))
        }
    }

    private var time: some View {
        Text(engine.timeString)
            .font(.system(size: 44, weight: .thin, design: .rounded).monospacedDigit())
            .foregroundColor(.white.opacity(engine.isRunning ? 0.96 : 0.62))
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.15), value: engine.timeString)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.13))
                Capsule()
                    .fill(kind.color)
                    .frame(width: max(0, geo.size.width * engine.progress))
            }
        }
        .frame(height: 3)
    }

    private var sequenceStrip: some View {
        HStack(spacing: 3) {
            ForEach(Array(engine.blocks.enumerated()), id: \.element.id) { position, block in
                Capsule()
                    .fill(block.kind.color)
                    .opacity(position == engine.index ? 1 : (position < engine.index ? 0.55 : 0.2))
                    .frame(width: block.kind == .focus ? 14 : 7, height: 3)
                    .onTapGesture { engine.jump(to: position) }
            }
        }
        .frame(height: 4)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            ControlButton(symbol: "arrow.counterclockwise", size: 12) { engine.reset() }
                .help("Restart this block")

            PrimaryButton(symbol: engine.isRunning ? "pause.fill" : "play.fill", color: kind.color) {
                engine.toggle()
            }

            ControlButton(symbol: "forward.end.fill", size: 12) { engine.skip() }
                .help("Skip to the next block")

            Spacer(minLength: 0)

            ControlButton(symbol: "gearshape.fill", size: 12, action: onSettings)
                .help("Settings")
        }
        .padding(.top, 1)
    }
}

private struct PrimaryButton: View {
    let symbol: String
    let color: Color
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .brightness(hovering ? 0.08 : 0)
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black.opacity(0.85))
                    .offset(x: symbol == "play.fill" ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct ControlButton: View {
    let symbol: String
    var size: CGFloat = 12
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white.opacity(hovering ? 0.95 : 0.5))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
