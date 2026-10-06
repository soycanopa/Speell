import AppKit

/// Composition root de la app: ventana, menú y ciclo de vida.
/// No habla con el C API de libghostty; eso vive en `GhosttyHost`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var host: GhosttyHost?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = GhosttyHost()
        self.host = host
        host.onSurfaceClose = { [weak self] in self?.window?.close() }

        MainMenu.install()

        let surface = SurfaceView(host: host)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Speell"
        window.contentMinSize = NSSize(width: 320, height: 200)
        window.contentView = surface
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(surface)
        self.window = window

        host.setFocus(NSApp.isActive)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Cerrar la última ventana cierra la app y mata el shell de la surface.
        true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        host?.setFocus(true)
    }

    func applicationDidResignActive(_ notification: Notification) {
        host?.setFocus(false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Libera libghostty, que termina los procesos hijos de sus surfaces.
        host?.shutdown()
    }
}
