import AppKit

/// Menú de la app para el spike: menú de aplicación con Salir (Cmd+Q).
/// El resto de menús entran en fases posteriores.
enum MainMenu {
    static func install() {
        let name = ProcessInfo.processInfo.processName
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Acerca de \(name)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Ocultar \(name)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Salir de \(name)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
