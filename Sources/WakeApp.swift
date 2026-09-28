import AppKit
import SwiftUI

@main
enum WakeMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let library = Library()
    let popover = NSPopover()
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var hosting: NSHostingController<Panel>!
    private var model: PanelModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let button = item.button
        let thickness = NSStatusBar.system.thickness
        let side = min(18, max(15, thickness - 6))
        let image = MenuIcon.image(side: side)
        button?.image = image
        button?.imageScaling = .scaleProportionallyDown
        button?.imagePosition = .imageOnly
        button?.toolTip = "Wake"
        button?.target = self
        button?.action = #selector(toggle)
        button?.sendAction(on: [.leftMouseDown])

        model = PanelModel(library: library)
        let panel = Panel(model: model) { [weak self] height in
            guard height > 1 else { return }
            self?.popover.contentSize = NSSize(width: 292, height: height)
        }
        hosting = NSHostingController(rootView: panel)
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 292, height: 168)
    }

    @objc private func toggle() {
        guard item.button != nil else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        NSApp.activate()
        // The click that opens the panel would also dismiss it if shown immediately.
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.item.button, !self.popover.isShown else { return }
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            button.highlight(true)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        item.button?.highlight(false)
    }
}
