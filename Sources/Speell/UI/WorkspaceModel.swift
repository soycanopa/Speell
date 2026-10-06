import Combine
import Foundation

/// Qué hilo abrir en una tab de agente. Lo elige el menú del `+`.
enum AgentTabChoice {
    case fresh
    case latest
    case session(SessionRef)
}

/// Página del menú del `+`. Es un desplegable: primero los tipos de tab, y
/// desde un agente sus opciones, y desde ahí sus hilos.
enum TabMenuPage: Equatable {
    case root
    case agent(AgentKind)
    case sessions(AgentKind)
}

/// Estado que consume la UI y las intenciones que emite.
/// La vista no conoce stores, ni libghostty, ni arma comandos.
/// Las intenciones se emiten desde el hilo principal (botones y menús).
@MainActor
final class WorkspaceModel: ObservableObject {
    @Published var projects: [Project] = []
    /// Proyectos cuyo path ya no existe en disco. La fila queda rota, no se borra.
    @Published var missingProjectIds: Set<UUID> = []
    @Published var tabs: [Tab] = []
    @Published var activeProjectId: UUID?
    @Published var activeTabId: UUID?

    /// Agentes que ya tienen adaptador. El menú del `+` muestra estos.
    @Published var availableAgents: [AgentKind] = []
    @Published var menuPage: TabMenuPage = .root
    @Published var agentSessions: [SessionRef] = []
    @Published var loadingSessions = false

    var onAddProject: () -> Void = {}
    var onSelectProject: (UUID) -> Void = { _ in }
    var onRemoveProject: (UUID) -> Void = { _ in }
    var onNewTerminal: () -> Void = {}
    var onNewAgentTab: (AgentKind, AgentTabChoice) -> Void = { _, _ in }
    var onOpenAgentMenu: (AgentKind) -> Void = { _ in }
    var onLoadAgentSessions: (AgentKind) -> Void = { _ in }
    var onTabMenuBack: () -> Void = {}
    var onResetTabMenu: () -> Void = {}
    var onSelectTab: (UUID) -> Void = { _ in }
    var onCloseTab: (UUID) -> Void = { _ in }

    var activeProject: Project? {
        projects.first { $0.id == activeProjectId }
    }
}
