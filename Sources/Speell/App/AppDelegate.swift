import AppKit
import Combine
import SwiftUI

/// Composition root de la app: ventana, menú y ciclo de vida.
/// No habla con el C API de libghostty ni con los stores; eso es del controller.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var host: GhosttyHost?
    private var controller: WorkspaceController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = GhosttyHost()
        let pane = TerminalPane()
        let controller = WorkspaceController(host: host, pane: pane)
        self.host = host
        self.controller = controller

        MainMenu.install()

        let sidebar = NSSplitViewItem(
            sidebarWithViewController: hosting(SidebarView(model: controller.model)))
        sidebar.minimumThickness = 180
        sidebar.maximumThickness = 320
        sidebar.canCollapse = true

        let split = NSSplitViewController()
        split.addSplitViewItem(sidebar)
        split.addSplitViewItem(NSSplitViewItem(
            viewController: hosting(MainContentView(model: controller.model, pane: pane))))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Speell"
        window.contentMinSize = NSSize(width: 480, height: 200)
        window.contentViewController = split
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        controller.model.$activeProjectId
            .sink { [weak self] id in
                guard let self else { return }
                self.window?.title = controller.projectName(for: id)
            }
            .store(in: &cancellables)

        controller.start()
        controller.focusActiveSurface()
    }

    /// Cerrar la última ventana cierra la app y mata los shells.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        host?.setFocus(true)
    }

    func applicationDidResignActive(_ notification: Notification) {
        host?.setFocus(false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
        host?.shutdown()
    }

    // MARK: Acciones del menú

    @objc func openProject(_ sender: Any?) {
        controller?.addProject()
    }

    @objc func newTab(_ sender: Any?) {
        controller?.newTab()
    }

    @objc func closeTab(_ sender: Any?) {
        controller?.closeActiveTab()
    }

    @objc func selectTabNumbered(_ sender: NSMenuItem) {
        controller?.selectTabNumber(sender.tag)
    }

    private func hosting<V: View>(_ view: V) -> NSViewController {
        let controller = NSViewController()
        controller.view = NSHostingView(rootView: view)
        return controller
    }
}
