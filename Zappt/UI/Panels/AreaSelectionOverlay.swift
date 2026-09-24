import AppKit

/// Result of an area selection: a rect in global Cocoa coordinates and its screen.
struct AreaSelectionResult {
    let rect: CGRect
    let screen: NSScreen
}

/// Presents a dimmed, drag-to-select overlay across all screens.
final class AreaSelectionController {
    private var panels: [AreaSelectionPanel] = []
    private var completion: ((AreaSelectionResult?) -> Void)?

    func present(completion: @escaping (AreaSelectionResult?) -> Void) {
        self.completion = completion
        for screen in NSScreen.screens {
            let panel = AreaSelectionPanel(screen: screen)
            panel.onSelect = { [weak self] result in self?.finish(result) }
            panel.onCancel = { [weak self] in self?.finish(nil) }
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        NSApp.activate(ignoringOtherApps: true)
        panels.first?.makeKey()
    }

    private func finish(_ result: AreaSelectionResult?) {
        for panel in panels { panel.orderOut(nil) }
        panels.removeAll()
        let block = completion
        completion = nil
        block?(result)
    }
}

final class AreaSelectionPanel: NSPanel {
    var onSelect: ((AreaSelectionResult) -> Void)?
    var onCancel: (() -> Void)?
    private let screenRef: NSScreen

    init(screen: NSScreen) {
        screenRef = screen
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setFrame(screen.frame, display: true)

        let view = AreaSelectionContentView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onSelect = { [weak self] localRect in
            guard let self else { return }
            let global = CGRect(x: self.screenRef.frame.minX + localRect.minX,
                                y: self.screenRef.frame.minY + localRect.minY,
                                width: localRect.width,
                                height: localRect.height)
            self.onSelect?(AreaSelectionResult(rect: global, screen: self.screenRef))
        }
        view.onCancel = { [weak self] in self?.onCancel?() }
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AreaSelectionContentView: NSView {
    var onSelect: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        guard currentRect.width > 1, currentRect.height > 1 else {
            drawHint()
            return
        }

        // Clear the selected region.
        NSColor.clear.set()
        let path = NSBezierPath(rect: currentRect)
        currentRect.fill(using: .clear)

        // Border around the selection.
        Theme.accentNSColor.setStroke()
        path.lineWidth = 2
        path.stroke()

        // Dimension label
        let dims = "\(Int(currentRect.width)) × \(Int(currentRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = dims.size(withAttributes: attrs)
        let labelRect = NSRect(x: currentRect.midX - size.width / 2 - 6,
                               y: currentRect.maxY + 6,
                               width: size.width + 12, height: size.height + 6)
        Theme.accentNSColor.setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 5, yRadius: 5).fill()
        dims.draw(at: NSPoint(x: labelRect.minX + 6, y: labelRect.minY + 3), withAttributes: attrs)
    }

    private func drawHint() {
        let hint = "Drag to select an area · Esc to cancel"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = hint.size(withAttributes: attrs)
        let point = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        hint.draw(at: point, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let p = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(x: min(start.x, p.x),
                             y: min(start.y, p.y),
                             width: abs(p.x - start.x),
                             height: abs(p.y - start.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { startPoint = nil }
        if currentRect.width > 8 && currentRect.height > 8 {
            onSelect?(currentRect)
        } else {
            onCancel?()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}
