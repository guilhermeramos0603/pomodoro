import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings.shared
    private let engine = PomodoroEngine.shared

    private var panel: FloatingPanel!
    private var effectView: DraggableEffectView!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var bag = Set<AnyCancellable>()

    private static let panelSize = NSSize(width: 250, height: 172)

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

        updateStatusTitle()
    }

    // MARK: - Panel

    private func buildPanel() {
        let rect = NSRect(origin: .zero, size: Self.panelSize)
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
        panel.setFrameOrigin(NSPoint(x: visible.maxX - Self.panelSize.width - 24,
                                     y: visible.maxY - Self.panelSize.height - 24))
    }

    private func applyAppearance() {
        guard let panel, let effectView else { return }
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
        menu.item(at: 5)?.title = (panel?.isVisible ?? false) ? "Hide Timer" : "Show Timer"
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
                contentRect: NSRect(x: 0, y: 0, width: 470, height: 430),
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
