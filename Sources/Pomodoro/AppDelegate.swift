import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let pomodoroFillScreen = Notification.Name("pomodoro.fillScreen")
    static let pomodoroResetSize = Notification.Name("pomodoro.resetSize")
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings.shared
    private let engine = PomodoroEngine.shared

    private var panel: FloatingPanel!
    private var effectView: DraggableEffectView!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var grip: ResizeGripView!
    private var bag = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildPanel()
        buildStatusItem()
        applyAppearance()

        settings.$data
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyAppearance()
                self?.engine.settingsChanged()
            }
            .store(in: &bag)

        engine.$remaining
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusTitle() }
            .store(in: &bag)

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            self.settings.data.windowOrigin = [Double(panel.frame.origin.x), Double(panel.frame.origin.y)]
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            self.settings.data.windowWidth = Double(panel.frame.width)
            self.settings.data.windowHeight = Double(panel.frame.height)
            self.settings.data.windowOrigin = [Double(panel.frame.origin.x), Double(panel.frame.origin.y)]
        }

        NotificationCenter.default.addObserver(
            forName: .pomodoroFillScreen, object: nil, queue: .main
        ) { [weak self] _ in self?.fillScreen() }

        NotificationCenter.default.addObserver(
            forName: .pomodoroResetSize, object: nil, queue: .main
        ) { [weak self] _ in self?.resetSize() }

        updateStatusTitle()
    }

    // MARK: - Panel

    private func buildPanel() {
        let rect = NSRect(origin: .zero, size: settings.panelSize)
        panel = FloatingPanel(contentRect: rect)

        let container = RoundedContainerView(frame: rect)
        container.autoresizingMask = [.width, .height]

        effectView = DraggableEffectView(frame: rect)
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.autoresizingMask = [.width, .height]
        container.addSubview(effectView)

        let host = DraggableHostingView(
            rootView: TimerView(
                engine: engine,
                settings: settings,
                onSettings: { [weak self] in self?.showSettings() },
                onHide: { [weak self] in self?.toggleTimerWindow() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        host.frame = rect
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)

        // Sits above the SwiftUI content so a drag in the corner resizes instead of moving.
        let gripSize: CGFloat = 15
        grip = ResizeGripView(frame: NSRect(x: rect.width - gripSize, y: 0, width: gripSize, height: gripSize))
        grip.autoresizingMask = [.minXMargin, .maxYMargin]
        grip.onResize = { [weak self] size in self?.setPanelSize(size) }
        container.addSubview(grip)

        panel.contentView = container
        placePanel()
        panel.orderFrontRegardless()
    }

    private func placePanel() {
        if let origin = settings.data.windowOrigin, origin.count == 2 {
            let point = NSPoint(x: origin[0], y: origin[1])
            let fits = NSScreen.screens.contains { $0.visibleFrame.insetBy(dx: -40, dy: -40).contains(point) }
            if fits {
                panel.setFrameOrigin(point)
                return
            }
        }
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - settings.panelSize.width - 24,
                                     y: visible.maxY - settings.panelSize.height - 24))
    }

    /// Resizes around the top-left corner, so the panel grows downward and to the right.
    private func setPanelSize(_ requested: CGSize) {
        guard let panel else { return }
        let screen = (panel.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let width = min(screen.width, max(AppSettings.minSize.width, requested.width)).rounded()
        let height = min(screen.height, max(AppSettings.minSize.height, requested.height)).rounded()
        guard abs(panel.frame.width - width) > 0.5 || abs(panel.frame.height - height) > 0.5 else { return }
        let top = panel.frame.maxY
        panel.setFrame(NSRect(x: panel.frame.origin.x, y: top - height, width: width, height: height),
                       display: true)
    }

    /// Covers the whole screen, minus the menu bar and the Dock — which stay reachable
    /// on purpose, so the panel can always be shrunk back from the menu bar item.
    @objc private func fillScreen() {
        guard let panel else { return }
        let visible = (panel.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        panel.setFrame(visible, display: true)
        panel.orderFrontRegardless()
    }

    @objc private func resetSize() {
        guard let panel else { return }
        let top = panel.frame.maxY
        panel.setFrame(NSRect(x: panel.frame.origin.x,
                              y: top - AppSettings.baseSize.height,
                              width: AppSettings.baseSize.width,
                              height: AppSettings.baseSize.height),
                       display: true)
        panel.orderFrontRegardless()
    }

    private func applyAppearance() {
        guard let panel, let effectView else { return }
        setPanelSize(CGSize(width: CGFloat(settings.data.windowWidth),
                            height: CGFloat(settings.data.windowHeight)))
        panel.alphaValue = settings.data.windowOpacity
        effectView.isHidden = settings.data.blurLevel == 0
        effectView.material = blurMaterial(for: settings.data.blurLevel)
        panel.collectionBehavior = settings.data.allSpaces
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            : [.moveToActiveSpace, .fullScreenAuxiliary]
    }

    // MARK: - Status item

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Pomodoro")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Start", action: #selector(toggleTimer), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Skip block", action: #selector(skipBlock), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Restart block", action: #selector(restartBlock), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Restart sequence", action: #selector(restartSequence), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Fill screen", action: #selector(fillScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reset size", action: #selector(resetSize), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Hide Timer", action: #selector(toggleTimerWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pomodoro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func updateStatusTitle() {
        statusItem?.button?.title = " " + engine.timeString
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(at: 0)?.title = engine.isRunning ? "Pause" : "Start"
        menu.item(withTitle: "Hide Timer")?.title = (panel?.isVisible ?? false) ? "Hide Timer" : "Show Timer"
        menu.item(withTitle: "Show Timer")?.title = (panel?.isVisible ?? false) ? "Hide Timer" : "Show Timer"
    }

    // MARK: - Actions

    @objc private func toggleTimer() { engine.toggle() }
    @objc private func skipBlock() { engine.skip() }
    @objc private func restartBlock() { engine.reset() }
    @objc private func restartSequence() { engine.resetAll() }

    @objc private func toggleTimerWindow() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 470, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Pomodoro Settings"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
