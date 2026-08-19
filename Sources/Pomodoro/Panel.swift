import AppKit
import SwiftUI

/// Borderless, always-on-top panel. Non-activating so clicking it never steals
/// focus from the app you are working in.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView, .resizable],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Every resize keeps the panel's proportions, so one scale factor drives the layout.
        contentAspectRatio = AppSettings.baseSize
        contentMinSize = NSSize(width: AppSettings.minWidth,
                                height: AppSettings.minWidth * AppSettings.baseSize.height / AppSettings.baseSize.width)
        contentMaxSize = NSSize(width: AppSettings.maxWidth,
                                height: AppSettings.maxWidth * AppSettings.baseSize.height / AppSettings.baseSize.width)
    }

    // Needed so buttons and the context menu respond without activating the app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The blurred backdrop. Dragging anywhere on it moves the window.
final class DraggableEffectView: NSVisualEffectView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDragged(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

/// SwiftUI content that still lets the window be dragged by its background.
final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }

    required init(rootView: Content) { super.init(rootView: rootView) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}

/// Clips the blur and the content to rounded corners that grow with the panel.
final class RoundedContainerView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerCurve = .continuous
        applyCornerRadius()
    }

    override func layout() {
        super.layout()
        applyCornerRadius()
    }

    private func applyCornerRadius() {
        let scale = bounds.width / AppSettings.baseSize.width
        layer?.cornerRadius = min(30, max(10, 16 * scale))
    }
}


/// Corner grip: drag it to resize the panel. Lives above the SwiftUI content so it
/// wins the mouse, and opts out of window dragging so a drag here never moves the window.
final class ResizeGripView: NSView {
    /// Called with the requested new width while dragging.
    var onResize: ((CGFloat) -> Void)?

    private var startWidth: CGFloat = 0
    private var startMouse: NSPoint = .zero

    override var mouseDownCanMoveWindow: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startWidth = window?.frame.width ?? 0
        startMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        onResize?(startWidth + (now.x - startMouse.x))
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath()
        for inset in stride(from: CGFloat(3), through: bounds.width - 3, by: 4) {
            path.move(to: NSPoint(x: bounds.maxX - inset, y: 3))
            path.line(to: NSPoint(x: bounds.maxX - 3, y: inset))
        }
        path.lineWidth = 1
        NSColor.white.withAlphaComponent(0.22).setStroke()
        path.stroke()
    }
}
