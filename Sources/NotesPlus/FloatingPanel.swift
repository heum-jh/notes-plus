import AppKit
import SwiftUI

/// Borderless SwiftUI panel that never takes focus away from Notes.
final class FloatingPanel<Content: View>: NSPanel {
    private let hosting: NSHostingView<Content>

    init(_ rootView: Content) {
        hosting = NSHostingView(rootView: rootView)
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        contentView = hosting
    }

    func show(topLeft point: NSPoint) {
        setContentSize(hosting.fittingSize)
        setFrameTopLeftPoint(point)
        orderFrontRegardless()
    }

    func show(bottomLeft point: NSPoint) {
        setContentSize(hosting.fittingSize)
        setFrameOrigin(point)
        orderFrontRegardless()
    }

    func show(bottomRight point: NSPoint) {
        let size = hosting.fittingSize
        setContentSize(size)
        setFrameOrigin(NSPoint(x: point.x - size.width, y: point.y))
        orderFrontRegardless()
    }
}
