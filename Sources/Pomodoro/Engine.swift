import AppKit
import Combine

/// Runs the sequence: which block we are on, how much is left, and what happens next.
final class PomodoroEngine: ObservableObject {
    static let shared = PomodoroEngine()

    @Published var blocks: [Block] = []
    @Published var index: Int = 0
    @Published var remaining: TimeInterval = 0
    @Published var isRunning: Bool = false

    private var endDate: Date?
    private var ticker: Timer?
    private let settings = AppSettings.shared

    private init() {
        blocks = settings.data.blocks
        remaining = currentBlock.duration
    }

    // MARK: - Derived state

    var currentBlock: Block {
        guard !blocks.isEmpty else { return Block(kind: .focus, minutes: 25) }
        return blocks[min(index, blocks.count - 1)]
    }

    var progress: Double {
        let total = currentBlock.duration
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    var timeString: String {
        let seconds = Int(remaining.rounded(.up))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%02d:%02d", m, s)
    }

    // MARK: - Controls

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        if remaining <= 0 { remaining = currentBlock.duration }
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        startTicker()
    }

    func pause() {
        guard isRunning else { return }
        remaining = max(0, endDate?.timeIntervalSinceNow ?? remaining)
        isRunning = false
        endDate = nil
        stopTicker()
    }

    /// Back to the start of the current block.
    func reset() {
        let wasRunning = isRunning
        remaining = currentBlock.duration
        if wasRunning { endDate = Date().addingTimeInterval(remaining) }
    }

    /// Whole sequence back to block 1, stopped.
    func resetAll() {
        pause()
        index = 0
        remaining = currentBlock.duration
    }

    func skip() { advance(playSound: false, respectAutoStart: false) }

    func jump(to newIndex: Int) {
        guard blocks.indices.contains(newIndex) else { return }
        let wasRunning = isRunning
        index = newIndex
        remaining = currentBlock.duration
        if wasRunning { endDate = Date().addingTimeInterval(remaining) }
    }

    /// Called when the user edits durations or the sequence in Settings.
    func settingsChanged() {
        let newBlocks = settings.data.blocks
        guard newBlocks != blocks else { return }
        blocks = newBlocks
        if index >= blocks.count { index = 0 }
        if !isRunning {
            remaining = currentBlock.duration
        } else {
            remaining = min(remaining, currentBlock.duration)
            endDate = Date().addingTimeInterval(remaining)
        }
    }

    // MARK: - Internals

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
        // .common keeps it ticking while the window is being dragged.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard isRunning, let end = endDate else { return }
        let left = end.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            advance(playSound: true, respectAutoStart: true)
        } else {
            remaining = left
        }
    }

    private func advance(playSound: Bool, respectAutoStart: Bool) {
        if playSound { chime() }

        pause()
        index = blocks.isEmpty ? 0 : (index + 1) % blocks.count
        remaining = currentBlock.duration

        let auto = currentBlock.kind.isBreak ? settings.data.autoStartBreaks
                                             : settings.data.autoStartFocus
        if respectAutoStart && auto { start() }
    }

    private func chime() {
        guard settings.data.soundEnabled else { return }
        NSSound(named: settings.data.soundName)?.play()
    }
}
