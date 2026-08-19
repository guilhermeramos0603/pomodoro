import SwiftUI

/// The panel UI. Everything is sized from `s`, the content scale — real point sizes, so text
/// stays sharp at any size. `s` is the size the user asked for, capped by what the window can
/// fit: growing the window does not grow the timer, it just gives it more room around it.
struct TimerView: View {
    @ObservedObject var engine: PomodoroEngine
    @ObservedObject var settings: AppSettings

    var onSettings: () -> Void
    var onHide: () -> Void
    var onQuit: () -> Void

    private var kind: BlockKind { engine.currentBlock.kind }

    var body: some View {
        GeometryReader { geo in
            let fits = min(geo.size.width / AppSettings.baseSize.width,
                           geo.size.height / AppSettings.baseSize.height)
            let s = max(0.45, min(fits, CGFloat(settings.data.contentScale)))

            ZStack {
                Color.black.opacity(settings.data.tintOpacity)

                VStack(spacing: 8 * s) {
                    header(s)
                    time(s)
                    progressBar(s)
                    sequenceStrip(s)
                    controls(s)
                }
                .padding(.horizontal, 16 * s)
                .padding(.vertical, 13 * s)
                .frame(width: AppSettings.baseSize.width * s)
            }
        }
        .contextMenu {
            Button("Settings…", action: onSettings)
            Button("Hide Timer", action: onHide)
            Divider()
            Button("Quit Pomodoro", action: onQuit)
        }
    }

    // MARK: - Pieces

    private func header(_ s: CGFloat) -> some View {
        HStack(spacing: 6 * s) {
            Circle()
                .fill(kind.color)
                .frame(width: 6 * s, height: 6 * s)
                .opacity(engine.isRunning ? 1 : 0.45)

            Text(kind.label.uppercased())
                .font(.system(size: 9.5 * s, weight: .semibold))
                .tracking(1.4 * s)
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(1)

            Spacer(minLength: 4 * s)

            Text("\(engine.index + 1)/\(max(engine.blocks.count, 1))")
                .font(.system(size: 9.5 * s, weight: .medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.35))
        }
    }

    private func time(_ s: CGFloat) -> some View {
        Text(engine.timeString)
            .font(.system(size: 44 * s, weight: .thin, design: .rounded).monospacedDigit())
            .foregroundColor(.white.opacity(engine.isRunning ? 0.96 : 0.62))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.15), value: engine.timeString)
    }

    private func progressBar(_ s: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(Color.white.opacity(0.80))
                    .frame(width: max(0, geo.size.width * engine.progress))
            }
        }
        .frame(height: 3 * s)
    }

    private func sequenceStrip(_ s: CGFloat) -> some View {
        HStack(spacing: 3 * s) {
            ForEach(Array(engine.blocks.enumerated()), id: \.element.id) { position, block in
                Capsule()
                    .fill(block.kind.color)
                    .opacity(position == engine.index ? 1 : (position < engine.index ? 0.55 : 0.2))
                    .frame(width: (block.kind == .focus ? 14 : (block.kind == .longBreak ? 10 : 6)) * s, height: 3 * s)
                    .onTapGesture { engine.jump(to: position) }
            }
        }
        .frame(height: 4 * s)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func controls(_ s: CGFloat) -> some View {
        HStack(spacing: 12 * s) {
            ControlButton(symbol: "arrow.counterclockwise", scale: s) { engine.reset() }
                .help("Restart this block")

            PrimaryButton(symbol: engine.isRunning ? "pause.fill" : "play.fill",
                          scale: s) { engine.toggle() }

            ControlButton(symbol: "forward.end", scale: s) { engine.skip() }
                .help("Skip to the next block")

            Spacer(minLength: 0)

            ControlButton(symbol: "gearshape", scale: s, action: onSettings)
                .help("Settings")
                // keeps the gear clear of the resize grip in the corner
                .padding(.trailing, 3 * s)
        }
        .padding(.top, 1 * s)
    }
}

private struct PrimaryButton: View {
    let symbol: String
    let scale: CGFloat
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(hovering ? 1.0 : 0.90))
                    .frame(width: 30 * scale, height: 30 * scale)
                Image(systemName: symbol)
                    .font(.system(size: 12 * scale, weight: .bold))
                    .foregroundColor(.black.opacity(0.80))
                    .offset(x: symbol == "play.fill" ? 1 * scale : 0)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct ControlButton: View {
    let symbol: String
    let scale: CGFloat
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundColor(.white.opacity(hovering ? 0.95 : 0.5))
                .frame(width: 22 * scale, height: 22 * scale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
