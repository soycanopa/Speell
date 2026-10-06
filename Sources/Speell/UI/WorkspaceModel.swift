import Combine
import Foundation

/// Qué sesión abrir en una tab de agente. Lo elige el menú del `+`.
enum AgentTabChoice {
    case fresh
    case session(SessionRef)
}

/// Petición de modal de sesiones. Se identifica por agente para que SwiftUI
/// sepa cuándo presentarlo y cuándo cerrarlo.
struct SessionPickerRequest: Identifiable, Equatable {
    let agent: AgentKind

    var id: String { agent.rawValue }
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
    /// Distancia desde el borde izquierdo del app bar hasta donde empieza la
    /// terminal. Lo publica el composition root cuando cambia el divider, para
    /// que el app bar pueda alinear los tabs con el borde de la terminal sin
    /// conocer el split.
    ///
    /// No es el ancho de la sidebar: es su borde derecho más el divisor del
    /// split. Los botones de ventana no se suman porque solo ocupan la parte
    /// de la franja que cae sobre la sidebar.
    @Published var contentLeadingOffset: CGFloat = 241

    /// Agentes que ya tienen adaptador. El menú del `+` muestra estos.
    @Published var availableAgents: [AgentKind] = []
    /// No nulo = modal de sesiones abierto para ese agente.
    @Published var sessionPicker: SessionPickerRequest?
    @Published var agentSessions: [SessionRef] = []
    @Published var loadingSessions = false

    var onAddProject: () -> Void = {}
    var onSelectProject: (UUID) -> Void = { _ in }
    var onRemoveProject: (UUID) -> Void = { _ in }
    var onNewTerminal: () -> Void = {}
    var onNewAgentTab: (AgentKind, AgentTabChoice) -> Void = { _, _ in }
    var onPickAgentSession: (AgentKind) -> Void = { _ in }
    var onCancelSessionPicker: () -> Void = {}
    var onSelectTab: (UUID) -> Void = { _ in }
    var onCloseTab: (UUID) -> Void = { _ in }

    var activeProject: Project? {
        projects.first { $0.id == activeProjectId }
    }
}
