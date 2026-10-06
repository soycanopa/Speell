import AppKit

/// Composition root del workspace: une stores, tabs y surfaces de libghostty.
/// La UI solo ve `WorkspaceModel`; ningún store arma comandos ni conoce la vista.
final class WorkspaceController {
    let model = WorkspaceModel()

    private let host: GhosttyHost
    private let pane: TerminalPane
    private let projects = ProjectStore()
    private let sessions = SessionStore()

    /// Última tab activa de cada proyecto. Solo en memoria.
    private var lastTabByProject: [UUID: UUID] = [:]

    init(host: GhosttyHost, pane: TerminalPane) {
        self.host = host
        self.pane = pane
        wireIntents()
    }

    private func wireIntents() {
        model.onAddProject = { [weak self] in self?.addProject() }
        model.onSelectProject = { [weak self] id in self?.selectProject(id: id) }
        model.onRemoveProject = { [weak self] id in self?.removeProject(id: id) }
        model.onNewTab = { [weak self] in self?.newTab() }
        model.onSelectTab = { [weak self] id in self?.selectTab(id: id) }
        model.onCloseTab = { [weak self] id in self?.closeTab(id: id) }
    }

    // MARK: Arranque y cierre

    /// Restaura el último proyecto activo con sus tabs. Las tabs de los demás
    /// proyectos no lanzan proceso hasta que se selecciona el proyecto.
    func start() {
        let ordered = projects.ordered
        guard !ordered.isEmpty else {
            refresh()
            return
        }
        let last = projects.lastActiveProjectId.flatMap { id in
            ordered.first { $0.id == id }
        }
        selectProject(id: (last ?? ordered[0]).id)
    }

    func focusActiveSurface() {
        guard let id = model.activeTabId, let view = pane.surfaceView(forTab: id) else { return }
        view.window?.makeFirstResponder(view)
    }

    /// Cierra la ventana: liberar las surfaces mata los procesos hijos.
    func shutdown() {
        pane.removeAll()
    }

    func projectName(for id: UUID?) -> String {
        guard let id, let project = projects.project(id: id) else { return "Speell" }
        return project.displayName
    }

    // MARK: Proyectos

    func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Abrir"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let project = projects.add(path: url.path)
        selectProject(id: project.id)

        // FLOW F1: fijar una carpeta abre su primera tab shell.
        if sessions.tabs(of: project.id).isEmpty {
            addShellTab(projectId: project.id)
        }
    }

    private func selectProject(id: UUID) {
        guard projects.project(id: id) != nil else { return }
        projects.touch(id: id)
        projects.setActive(id: id)

        ensureSurfaces(projectId: id)

        let tabs = sessions.tabs(of: id)
        let wanted = lastTabByProject[id].flatMap { previous in
            tabs.first { $0.id == previous }
        }
        show(tabId: (wanted ?? tabs.last)?.id)
        refresh()
        focusActiveSurface()
    }

    private func removeProject(id: UUID) {
        guard let project = projects.project(id: id) else { return }

        let alert = NSAlert()
        alert.messageText = "¿Quitar \(project.displayName) de la sidebar?"
        alert.informativeText = "La carpeta no se borra del disco. Sus tabs se cierran y sus procesos mueren."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quitar")
        alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        for tab in sessions.tabs(of: id) {
            pane.removeSurface(forTab: tab.id)
        }
        sessions.removeTabs(of: id)
        projects.remove(id: id)
        lastTabByProject[id] = nil

        if model.activeProjectId == id {
            model.activeTabId = nil
            pane.show(tabId: nil)
            if let next = projects.ordered.first {
                selectProject(id: next.id)
            } else {
                refresh()
            }
        } else {
            refresh()
        }
    }

    // MARK: Tabs

    func newTab() {
        guard let project = model.activeProject else { return }
        addShellTab(projectId: project.id)
    }

    func closeActiveTab() {
        guard let id = model.activeTabId else { return }
        closeTab(id: id)
    }

    func selectTabNumber(_ number: Int) {
        let tabs = model.tabs
        guard number >= 1, number <= tabs.count else { return }
        selectTab(id: tabs[number - 1].id)
    }

    private func addShellTab(projectId: UUID) {
        guard let project = projects.project(id: projectId) else { return }
        let cwd = FileManager.default.fileExists(atPath: project.path)
            ? project.path
            : NSHomeDirectory()

        let tab = Tab(
            projectId: projectId,
            kind: .shell,
            cwd: cwd,
            title: shellTitle(for: cwd))
        sessions.add(tab)
        installSurface(for: tab)
        show(tabId: tab.id)
        projects.touch(id: projectId)
        refresh()
        focusActiveSurface()
    }

    private func selectTab(id: UUID) {
        guard sessions.tabs.contains(where: { $0.id == id }) else { return }
        show(tabId: id)
        focusActiveSurface()
    }

    private func closeTab(id: UUID) {
        guard let tab = sessions.tabs.first(where: { $0.id == id }) else { return }
        let siblings = sessions.tabs(of: tab.projectId)
        let index = siblings.firstIndex { $0.id == id } ?? 0

        // Quitar la surface del pane la libera y mata el proceso de esa tab.
        pane.removeSurface(forTab: id)
        sessions.remove(id: id)

        if model.activeTabId == id {
            let remaining = sessions.tabs(of: tab.projectId)
            if remaining.isEmpty {
                show(tabId: nil)
            } else {
                show(tabId: remaining[min(index, remaining.count - 1)].id)
            }
        }

        refresh()
        focusActiveSurface()
    }

    // MARK: Surfaces

    private func ensureSurfaces(projectId: UUID) {
        for tab in sessions.tabs(of: projectId) where pane.surfaceView(forTab: tab.id) == nil {
            installSurface(for: tab)
        }
    }

    private func installSurface(for tab: Tab) {
        let cwd = FileManager.default.fileExists(atPath: tab.cwd)
            ? tab.cwd
            : fallbackCwd(for: tab)
        let view = SurfaceView(host: host, cwd: cwd)
        view.onCloseRequest = { [weak self] in self?.closeTab(id: tab.id) }
        pane.install(view, forTab: tab.id)
    }

    private func fallbackCwd(for tab: Tab) -> String {
        guard let project = projects.project(id: tab.projectId),
              FileManager.default.fileExists(atPath: project.path) else {
            return NSHomeDirectory()
        }
        return project.path
    }

    private func show(tabId: UUID?) {
        pane.show(tabId: tabId)
        model.activeTabId = tabId
        if let tabId, let tab = sessions.tabs.first(where: { $0.id == tabId }) {
            lastTabByProject[tab.projectId] = tabId
        }
    }

    private func shellTitle(for cwd: String) -> String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty || cwd == NSHomeDirectory() ? "Terminal" : name
    }

    // MARK: Estado para la UI

    private func refresh() {
        let ordered = projects.ordered
        model.projects = ordered
        model.missingProjectIds = Set(
            ordered.filter { !FileManager.default.fileExists(atPath: $0.path) }.map(\.id))

        let active = projects.lastActiveProjectId.flatMap { id in
            ordered.contains { $0.id == id } ? id : nil
        }
        model.activeProjectId = active ?? ordered.first?.id
        model.tabs = model.activeProjectId.map { sessions.tabs(of: $0) } ?? []

        if let current = model.activeTabId, !model.tabs.contains(where: { $0.id == current }) {
            model.activeTabId = nil
        }
    }
}
