import Foundation

/// Instalación de surfaces de libghostty y el rearmado del comando de cada tab
/// desde su puntero guardado.
extension WorkspaceController {
    func ensureSurfaces(projectId: UUID) {
        for tab in sessions.tabs(of: projectId) where pane.surfaceView(forTab: tab.id) == nil {
            guard tab.kind == .agent, tab.resumeQuality == .fresh,
                  let agent = tab.agent, let adapter = adapters[agent] else {
                installSurface(for: tab)
                continue
            }

            // Restaurar una tab de agente sin puntero: "último de la carpeta"
            // solo existe si el CLI tiene sesiones aquí. Con la carpeta vacía,
            // `continueLatest` es un error garantizado (grok: "No session
            // found for current directory") y la tab muere. El listado del
            // propio adaptador decide: con sesiones, retoma el último; sin
            // ellas, conversación nueva. Es async: el listado puede tardar.
            let cwd = resolvedCwd(for: tab)
            Task { @MainActor [weak self] in
                guard let self, self.sessions.tabs.contains(where: { $0.id == tab.id }) else { return }
                var restored = tab
                if !(await adapter.list(cwd: cwd)).isEmpty {
                    restored.resumeQuality = .latestInDir
                    self.sessions.update(restored)
                }
                guard self.pane.surfaceView(forTab: tab.id) == nil else { return }
                self.installSurface(for: restored)
                if self.model.activeTabId == tab.id {
                    self.focusActiveSurface()
                }
            }
        }
    }

    func installSurface(for tab: Tab) {
        installSurface(for: tab, command: command(for: tab))
    }

    func installSurface(for tab: Tab, command: Command) {
        let view = SurfaceView(host: host, command: command)
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
        if tab.resumeQuality == .fresh {
            // Inalcanzable tras la promoción de ensureSurfaces; si llegara, lo
            // honesto es una conversación nueva.
            return adapter.launch(cwd: cwd)
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

    func show(tabId: UUID?) {
        pane.show(tabId: tabId)
        model.activeTabId = tabId
        if let tabId, let tab = sessions.tabs.first(where: { $0.id == tabId }) {
            lastTabByProject[tab.projectId] = tabId
        }
    }
}
