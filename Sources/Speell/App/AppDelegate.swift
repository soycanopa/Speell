import AppKit
import Combine
import SwiftUI

/// Composition root de la app: ventana, menú y ciclo de vida.
/// No habla con el C API de libghostty ni con los stores; eso es del controller.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var split: NSSplitViewController?
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

        // Item plano, no `sidebarWithViewController`: el behavior de sidebar
        // instala detrás de toda la columna el material vibrante de macOS, que
        // pintaba los 8 pt de separación con otro tono y tapaba las esquinas
        // redondeadas del clip. Speell pinta sus propias superficies, así que
        // detrás no tiene que haber nada del sistema.
        let sidebar = NSSplitViewItem(
            viewController: hosting(SidebarView(model: controller.model)))
        sidebar.minimumThickness = 180
        sidebar.maximumThickness = 320
        sidebar.canCollapse = true
        // Con ambos items en 250 el divider deriva proporcionalmente al
        // redimensionar la ventana. La sidebar fija su ancho, como hacía el
        // behavior de sidebar, y la terminal cede.
        sidebar.holdingPriority = NSLayoutConstraint.Priority(260)

        let split = WorkspaceSplitViewController()
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
        // Un solo fondo para toda la ventana. Antes era el gris del sistema, y
        // los huecos de 8 px —el margen exterior y la separación entre la
        // sidebar y la terminal— se leían como un canal claro en medio de dos
        // superficies oscuras.
        window.backgroundColor = SpeellPalette.windowBackground

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
        let pad = SpeellPalette.windowPadding
        let topPad = SpeellPalette.windowTopPadding

        // Todo el contenido —app bar, sidebar y terminal— entra dentro del
        // margen. AppKit mide desde abajo, así que el margen va en `y` del app
        // bar y el split arranca sobre él.
        split.view.frame = NSRect(
            x: pad, y: pad,
            width: container.bounds.width - pad * 2,
            height: container.bounds.height - barHeight - topPad - pad)
        split.view.autoresizingMask = [.width, .height]

        let appBar = NSHostingView(rootView: AppBarView(model: controller.model))
        appBar.frame = NSRect(
            x: pad, y: container.bounds.height - barHeight - topPad,
            width: container.bounds.width - pad * 2,
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
        centerWindowControls(in: window, on: appBar)
        // El centro del app bar cambia con el alto de la ventana: los botones
        // se vuelven a centrar en cada resize y en cada activación.
        window.delegate = self
        // `center()` usa la pantalla principal del proceso, que con varias
        // pantallas puede no ser la que el usuario tiene delante. Se ancla al
        // área visible de `NSScreen.main` para que la ventana aparezca donde se
        // está mirando.
        let initialSize = NSSize(width: 1000, height: 640 + barHeight)
        if let visible = NSScreen.main?.visibleFrame {
            window.setFrame(
                NSRect(
                    x: visible.midX - initialSize.width / 2,
                    y: visible.midY - initialSize.height / 2,
                    width: initialSize.width,
                    height: initialSize.height),
                display: true)
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        // Lanzada fuera de Launch Services —con `nohup`, en desarrollo— la app
        // arranca inactiva y la ventana no toma el foco. Ghostty activa igual
        // (su AppDelegate): síncrono en este punto no prende, va en el
        // siguiente ciclo del runloop.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
        self.window = window
        self.split = split
        // El split no admite delegate externo, así que el ancho se publica desde
        // una subclase suya que ya está enganchada.
        split.sidebarItem = sidebar
        split.onSidebarWidthChanged = { [weak self] width in
            MainActor.assumeIsolated {
                self?.controller?.model.contentLeadingOffset = width
            }
        }
        controller.model.contentLeadingOffset = split.contentLeadingOffset ?? 241

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

    // MARK: Alineación de los botones de ventana

    /// macOS coloca los botones de ventana en su propia barra de título —una
    /// vista de 28 pt cuyas coordenadas no controla Speell— y el sistema
    /// recorta el glifo en una línea fija a ~27,5 pt del tope, sin importar
    /// dónde esté el frame (medido moviendo el frame en vivo). El círculo
    /// completo mide ~11 pt: su centro no puede pasar de ~21 sin cortarse.
    /// La referencia es absoluta —el centro del glifo a ~20,5 del tope—, no
    /// relativa al alto del app bar, para que los puntos no suban y bajen
    /// con la franja.
    private func centerWindowControls(in window: NSWindow, on bar: NSView) {
        guard let content = window.contentView else { return }
        let barCenter = CGPoint(x: 0, y: bar.frame.midY + 1)

        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton),
        ].compactMap { $0 }

        for button in buttons {
            guard let host = button.superview else { continue }
            let center = content.convert(barCenter, to: host)
            button.setFrameOrigin(
                CGPoint(x: button.frame.origin.x, y: center.y - button.frame.height / 2))
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let bar = window.contentView?.subviews.last else { return }
        centerWindowControls(in: window, on: bar)
    }
}
