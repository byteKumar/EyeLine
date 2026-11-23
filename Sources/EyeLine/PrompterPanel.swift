import AppKit
import Combine
import EyeLineCore
import SwiftUI

/// Borderless floating panel that never takes focus from the app you're presenting in.
final class PrompterPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        // Above the menu bar, so it can sit flush against the notch.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// AppKit normally pushes windows below the menu bar; keep ours where we put it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Hosting view that reacts to the first click and turns scroll gestures into scrubbing.
final class PrompterHostingView<Content: View>: NSHostingView<Content> {
    var onScroll: ((CGFloat) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 12
        onScroll?(-dy)
    }
}

@MainActor
final class PrompterController {
    let model: PrompterModel
    let panel = PrompterPanel()
    private var bag = Set<AnyCancellable>()
    private var screen: NSScreen

    init(model: PrompterModel) {
        self.model = model
        screen = Self.preferredScreen()
        model.topInset = Self.topInset(of: screen)

        let host = PrompterHostingView(rootView: PrompterView(model: model, onResizeDrag: { [weak self] in
            self?.resizeToMouse()
        }))
        host.onScroll = { [weak model] dy in model?.scrub(by: dy) }
        panel.contentView = host

        model.$size.sink { [weak self] size in self?.layout(size: size) }.store(in: &bag)
        model.$isVisible.sink { [weak self] visible in
            guard let self else { return }
            if visible { self.panel.orderFrontRegardless() } else { self.panel.orderOut(nil) }
        }.store(in: &bag)
        model.$visibleInCaptures.sink { [weak self] visible in
            self?.panel.sharingType = visible ? .readOnly : .none
        }.store(in: &bag)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.screenChanged() }
            .store(in: &bag)
    }

    /// The built-in display with a camera notch if there is one, else the main display.
    static func preferredScreen() -> NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    static func topInset(of screen: NSScreen) -> CGFloat {
        let notch = screen.safeAreaInsets.top
        if notch > 0 { return notch }
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return max(menuBar, 24)
    }

    private func layout(size: CGSize) {
        panel.setFrame(PrompterGeometry.panelFrame(size: size, screen: screen.frame), display: true)
    }

    private func resizeToMouse() {
        let size = PrompterGeometry.size(forHandleAt: NSEvent.mouseLocation, screen: screen.frame)
        if size != model.size { model.size = size }
    }

    private func screenChanged() {
        screen = Self.preferredScreen()
        model.topInset = Self.topInset(of: screen)
        layout(size: model.size)
    }
}
