import AppKit

/// Menú de la app. Los atajos con Command ganan a los bindings de libghostty,
/// porque AppKit consulta el menú principal antes de entregar la tecla a la vista.
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

        let fileMenu = NSMenu(title: "Archivo")
        fileMenu.addItem(
            withTitle: "Abrir carpeta…",
            action: #selector(AppDelegate.openProject(_:)),
            keyEquivalent: "o")
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "Nueva terminal",
            action: #selector(AppDelegate.newTab(_:)),
            keyEquivalent: "t")
        fileMenu.addItem(
            withTitle: "Cerrar tab",
            action: #selector(AppDelegate.closeTab(_:)),
            keyEquivalent: "w")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu

        let viewMenu = NSMenu(title: "Ver")
        let toggleSidebar = viewMenu.addItem(
            withTitle: "Ocultar sidebar",
            action: #selector(NSSplitViewController.toggleSidebar(_:)),
            keyEquivalent: "s")
        toggleSidebar.keyEquivalentModifierMask = [.command, .control]
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu

        let tabMenu = NSMenu(title: "Tab")
        for number in 1...9 {
            let item = tabMenu.addItem(
                withTitle: "Tab \(number)",
                action: #selector(AppDelegate.selectTabNumbered(_:)),
                keyEquivalent: "\(number)")
            item.tag = number
        }
        let tabMenuItem = NSMenuItem()
        tabMenuItem.submenu = tabMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(viewMenuItem)
        mainMenu.addItem(tabMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
