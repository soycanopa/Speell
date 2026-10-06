import AppKit

/// Composition root del workspace: une stores, adaptadores, tabs y surfaces de
/// libghostty. La UI solo ve `WorkspaceModel`; ninguna vista arma un comando.
/// Todo pasa en el hilo principal: los diálogos y las surfaces lo exigen.
@MainActor
final class WorkspaceController {
    let model = WorkspaceModel()

    private let host: GhosttyHost
    private let pane: TerminalPane
    private let projects = ProjectStore()
    private let sessions = SessionStore()

    /// Un adaptador por agente. La fase 3 suma OpenCode 2 y Agy.
    private let adapters: [AgentKind: AgentAdapter] = [
        .grok: GrokAdapter(),
    ]

    /// Última tab activa de cada proyecto. Solo en memoria.
    private var lastTabByProject: [UUID: UUID] = [:]

    init(host: GhosttyHost, pane: TerminalPane) {
        self.host = host
        self.pane = pane
        wireIntents()
        model.availableAgents = AgentKind.allCases.filter { adapters[$0] != nil }
    }

    private func wireIntents() {
        model.onAddProject = { [weak self] in self?.addProject() }
        model.onSelectProject = { [weak self] id in self?.selectProject(id: id) }
        model.onRemoveProject = { [weak self] id in self?.removeProject(id: id) }
        model.onNewTerminal = { [weak self] in self?.newShellTab() }
        model.onNewAgentTab = { [weak self] agent, choice in self?.newAgentTab(agent: agent, choice: choice) }
        model.onLoadAgentSessions = { [weak self] agent in self?.loadAgentSessions(agent: agent) }
        model.onCloseAgentSessions = { [weak self] in self?.closeAgentSessions() }
        model.onSelectTab = { [weak self] id in self?.selectTab(id: id) }
        model.onCloseTab = { [weak self] id in self?.closeTab(id: id) }
    }

    // MARK: Arranque y cierre

    /// Restaura el último proyecto activo con sus tabs, rearmando el comando de
    /// cada una desde su puntero. Las tabs de los demás proyectos no lanzan
    /// proceso hasta que se selecciona el proyecto.
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

    /// Botón del vacío y ⌘T: una terminal, sin preguntar.
    func newShellTab() {
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

    // MARK: Agentes

    private func newAgentTab(agent: AgentKind, choice: AgentTabChoice) {
        guard let project = model.activeProject, let adapter = adapters[agent] else { return }
        addAgentTab(projectId: project.id, adapter: adapter, choice: choice)
        closeAgentSessions()
    }

    /// La lista de hilos se pide al abrir "Elegir hilo…", no en cada `+`.
    /// Corre fuera del hilo principal; el popover muestra "Buscando hilos…".
    private func loadAgentSessions(agent: AgentKind) {
        guard let project = model.activeProject, let adapter = adapters[agent] else { return }
        model.sessionListAgent = agent
        model.agentSessions = []
        model.loadingSessions = true

        let cwd = project.path
        Task { @MainActor in
            let sessions = await adapter.list(cwd: cwd)
            model.agentSessions = sessions
            model.loadingSessions = false
        }
    }

    private func closeAgentSessions() {
        model.sessionListAgent = nil
        model.agentSessions = []
        model.loadingSessions = false
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

    private func addAgentTab(projectId: UUID, adapter: AgentAdapter, choice: AgentTabChoice) {
        guard let project = projects.project(id: projectId) else { return }
        let cwd = FileManager.default.fileExists(atPath: project.path)
            ? project.path
            : NSHomeDirectory()

        let tab: Tab
        switch choice {
        case .fresh:
            // Speell propone el id y el CLI lo respeta: el puntero nace fiable.
            let sessionId = UUID().uuidString.lowercased()
            tab = Tab(
                projectId: projectId,
                kind: .agent,
                cwd: cwd,
                title: adapter.kind.displayName,
                agent: adapter.kind,
                sessionId: sessionId,
                resumeQuality: .exact)
        case .latest:
            tab = Tab(
                projectId: projectId,
                kind: .agent,
                cwd: cwd,
                title: adapter.kind.displayName,
                agent: adapter.kind,
                sessionId: nil,
                resumeQuality: .latestInDir)
        case .session(let reference):
            tab = Tab(
                projectId: projectId,
                kind: .agent,
                cwd: cwd,
                title: reference.title,
                agent: adapter.kind,
                sessionId: reference.id,
                resumeQuality: .exact)
        }

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
        let view = SurfaceView(host: host, command: command(for: tab))
        view.onCloseRequest = { [weak self] in self?.closeTab(id: tab.id) }
        pane.install(view, forTab: tab.id)
    }

    /// Rearma el comando desde el puntero guardado. No se persiste el comando:
    /// el flag del CLI es del adaptador, no del disco.
    private func command(for tab: Tab) -> Command {
        let cwd = resolvedCwd(for: tab)
        guard tab.kind == .agent, let agent = tab.agent, let adapter = adapters[agent] else {
            return .shell(in: cwd)
        }
        if let id = tab.sessionId, tab.resumeQuality != .latestInDir {
            return adapter.resume(cwd: cwd, id: id)
        }
        return adapter.continueLatest(cwd: cwd)
    }

    private func resolvedCwd(for tab: Tab) -> String {
        if FileManager.default.fileExists(atPath: tab.cwd) { return tab.cwd }
        if let project = projects.project(id: tab.projectId),
           FileManager.default.fileExists(atPath: project.path) {
            return project.path
        }
        return NSHomeDirectory()
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
