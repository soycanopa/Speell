import AppKit

/// Composition root del workspace: une stores, adaptadores, tabs y surfaces de
/// libghostty. La UI solo ve `WorkspaceModel`; ninguna vista arma un comando.
/// Todo pasa en el hilo principal: los diálogos y las surfaces lo exigen.
/// Las responsabilidades viven en las extensiones por archivo:
/// proyectos, tabs, tabs de agente y surfaces.
@MainActor
final class WorkspaceController {
    let model = WorkspaceModel()

    let host: GhosttyHost
    let pane: TerminalPane
    let projects = ProjectStore()
    let sessions = SessionStore()

    /// Un adaptador por agente, el contrato de docs/decisions/0003 y 0004.
    let adapters: [AgentKind: AgentAdapter] = [
        .grok: GrokAdapter(),
        .opencode2: OpenCode2Adapter(),
        .agy: AgyAdapter(),
    ]

    /// Última tab activa de cada proyecto. Solo en memoria.
    var lastTabByProject: [UUID: UUID] = [:]

    /// Preferencias de agentes persistidas (settings → Agentes).
    private var agentPreferences = AgentPreferences()
    private let settingsStore: JSONStore

    /// Nombre del archivo de preferencias de agentes en Application Support.
    private static let agentPreferencesFile = "agent-preferences"

    init(host: GhosttyHost, pane: TerminalPane) {
        self.host = host
        self.pane = pane
        self.settingsStore = .applicationSupport
        agentPreferences = settingsStore.load(AgentPreferences.self, named: Self.agentPreferencesFile) ?? AgentPreferences()
        wireIntents()
        model.agentPreferences = agentPreferences
        model.availableAgents = AgentKind.allCases.filter {
            adapters[$0] != nil && agentPreferences.isEnabled($0)
        }
        model.terminalBackgroundHex = TerminalPalette.backgroundHex(
            in: TerminalPalette.applicationSupportDirectory)
    }

    private func wireIntents() {
        model.onAddProject = { [weak self] in self?.addProject() }
        model.onSelectProject = { [weak self] id in self?.selectProject(id: id) }
        model.onRemoveProject = { [weak self] id in self?.removeProject(id: id) }
        model.onNewTerminal = { [weak self] in self?.newShellTab() }
        model.onNewAgentTab = { [weak self] agent, choice in self?.newAgentTab(agent: agent, choice: choice) }
        model.onPickAgentSession = { [weak self] agent in self?.pickAgentSession(agent: agent) }
        model.onCancelSessionPicker = { [weak self] in self?.cancelSessionPicker() }
        model.onSelectTab = { [weak self] id in self?.selectTab(id: id) }
        model.onCloseTab = { [weak self] id in self?.closeTab(id: id) }
        model.onAgentToggle = { [weak self] agent, enabled in
            guard let self else { return }
            self.agentPreferences.setEnabled(enabled, for: agent)
            self.settingsStore.save(self.agentPreferences, named: Self.agentPreferencesFile)
            self.model.agentPreferences = self.agentPreferences
            self.model.availableAgents = AgentKind.allCases.filter {
                self.adapters[$0] != nil && self.agentPreferences.isEnabled($0)
            }
        }
        model.onAppearanceChange = { [weak self] hex, fontFamily, fontSize in
            guard let self else { return }
            let directory = TerminalPalette.applicationSupportDirectory
            var values = TerminalPalette.values(in: directory)
            values["background"] = hex
            if let fontFamily {
                values["font-family"] = fontFamily
            } else {
                values.removeValue(forKey: "font-family")
            }
            values["font-size"] = String(format: "%.0f", fontSize)
            TerminalPalette.writeOverride(values: values, in: directory)
            self.model.terminalBackgroundHex = hex
            self.host.refreshConfig(on: self.pane.allSurfaces())
        }
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

    // MARK: Estado para la UI

    func refresh() {
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
