import AppKit
import SwiftUI

/// Dev helper: `Pomodoro --snapshot /path/out.png` renders the timer panel to a PNG
/// and exits. Useful for checking the layout without Screen Recording permission.
/// The system blur cannot be captured this way, so a fake backdrop is drawn instead.
enum Snapshot {
    static func run(path: String, width: CGFloat, height: CGFloat?) -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let size = NSSize(width: width,
                          height: height ?? (width * AppSettings.baseSize.height / AppSettings.baseSize.width).rounded())
        let rect = NSRect(origin: .zero, size: size)

        let root = ZStack {
            LinearGradient(colors: [Color(red: 0.35, green: 0.30, blue: 0.45),
                                    Color(red: 0.15, green: 0.20, blue: 0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            TimerView(engine: PomodoroEngine.shared,
                      settings: AppSettings.shared,
                      onSettings: {}, onHide: {}, onQuit: {})
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        let host = NSHostingView(rootView: root)
        host.frame = rect

        let window = NSWindow(contentRect: rect, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = host
        window.orderBack(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: rect) else { exit(1) }
            host.cacheDisplay(in: rect, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
            try? png.write(to: URL(fileURLWithPath: path))
            exit(0)
        }

        app.run()
        exit(0)
    }
}
