import AppKit
import SwiftUI

/// Borderless, always-on-top panel. Non-activating so clicking it never steals
/// focus from the app you are working in.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
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

/// Clips the blur and the content to rounded corners.
final class RoundedContainerView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        if #available(macOS 14.0, *) { layer?.cornerCurve = .continuous }
    }
}
