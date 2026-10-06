import AppKit
import Combine
import SwiftUI

/// Composition root de la app: ventana, menú y ciclo de vida.
/// No habla con el C API de libghostty ni con los stores; eso es del controller.
@MainActor
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

        // Sin barra de título visible: la zona de arriba la ocupa Speell. Los botones
        // de ventana se quedan donde macOS los pone, sobre la sidebar, y la
        // barra de tabs arranca a su derecha.
        //
        // `fullSizeContentView` va en el `styleMask` de creación, no con un
        // `insert` después: insertado más tarde no recalcula el layout y la
        // franja de arriba queda reservada, con los tabs una fila más abajo de
        // donde deberían.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.title = "Speell"
        window.contentMinSize = NSSize(width: 480, height: 200)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // El app bar y el split no son `contentViewController`: hace falta un
        // contenedor para apilar el bar encima del contenido y que ambos ocupen
        // el ancho completo. El split conserva el colapso y el arrastre
        // nativos de macOS porque sigue siendo un `NSSplitViewController`.
        //
        // AppKit mide desde abajo, así que el bar va arriba: su `y` es el alto
        // del contenedor menos el del bar.
        let container = NSView(
            frame: NSRect(x: 0, y: 0, width: 1000, height: 640))
        let barHeight = AppBarView.height

        split.view.frame = NSRect(
            x: 0, y: 0,
            width: container.bounds.width,
            height: container.bounds.height - barHeight)
        split.view.autoresizingMask = [.width, .height]

        let appBar = NSHostingView(rootView: AppBarView(model: controller.model))
        appBar.frame = NSRect(
            x: 0, y: container.bounds.height - barHeight,
            width: container.bounds.width,
            height: barHeight)
        appBar.autoresizingMask = [.width, .minYMargin]

        container.addSubview(split.view)
        container.addSubview(appBar)
        window.contentView = container
        // Con `fullSizeContentView` el content view ocupa los 640 enteros y el
        // app bar se apila arriba, así que la terminal pierde los 38 de la
        // franja. Se compensa para no entregar menos terminal que antes.
        window.setContentSize(NSSize(width: 1000, height: 640 + barHeight))
        split.splitView.setPosition(240, ofDividerAt: 0)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        controller.model.$activeProjectId
            .sink { [weak self] id in
                // `sink` no está aislado; el estado y la ventana viven en main.
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.window?.title = controller.projectName(for: id)
                }
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
        // ⌘T coincide con la etiqueta del menú ("Nueva terminal"). Los agentes
        // viven en el menú del `+`.
        controller?.newShellTab()
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
