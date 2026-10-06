import Foundation

/// Tabs de agente: el modal de sesiones y la creación con el comando del
/// adaptador. La lista se pide solo al abrir el modal, no en cada `+`.
extension WorkspaceController {
    func newAgentTab(agent: AgentKind, choice: AgentTabChoice) {
        guard let project = model.activeProject, let adapter = adapters[agent] else { return }
        addAgentTab(projectId: project.id, adapter: adapter, choice: choice)
        cancelSessionPicker()
    }

    /// Abre el modal de sesiones y pide la lista al CLI. El modal muestra
    /// "Buscando sesiones…" hasta que llega.
    func pickAgentSession(agent: AgentKind) {
        guard let project = model.activeProject, let adapter = adapters[agent] else { return }
        model.agentSessions = []
        model.loadingSessions = true
        model.sessionPicker = SessionPickerRequest(agent: agent)

        let cwd = project.path
        Task { @MainActor in
            let sessions = await adapter.list(cwd: cwd)
            model.agentSessions = sessions
            model.loadingSessions = false
        }
    }

    func cancelSessionPicker() {
        model.sessionPicker = nil
        model.agentSessions = []
        model.loadingSessions = false
    }

    func addAgentTab(projectId: UUID, adapter: AgentAdapter, choice: AgentTabChoice) {
        guard let project = projects.project(id: projectId) else { return }
        let cwd = FileManager.default.fileExists(atPath: project.path)
            ? project.path
            : NSHomeDirectory()

        let tab: Tab
        switch choice {
        case .fresh:
            // Conversación nueva sin puntero: el id lo genera y guarda el CLI
            // (docs/decisions/0005). Al restaurar, la tab pasa a "último de la
            // carpeta" (FLOW F3).
            tab = Tab(
                projectId: projectId,
                kind: .agent,
                cwd: cwd,
                title: adapter.kind.displayName,
                agent: adapter.kind,
                sessionId: nil,
                resumeQuality: .fresh)
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
        if tab.resumeQuality == .fresh {
            // La sesión nueva corre `launch`, no el rearmado de restore: para
            // Agy `--continue` retomaría el último hilo en vez de abrir uno
            // nuevo (FLOW F2).
            installSurface(for: tab, command: adapter.launch(cwd: cwd))
        } else {
            installSurface(for: tab)
        }
        show(tabId: tab.id)
        projects.touch(id: projectId)
        refresh()
        focusActiveSurface()
    }
}
