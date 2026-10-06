import Foundation

/// Qué corre en la tab.
enum TabKind: String, Codable {
    case shell
    case agent
}

/// Agentes del MVP. Los adaptadores llegan en la fase 2.
enum AgentKind: String, Codable, CaseIterable {
    case grok
    case opencode2
    case agy

    var displayName: String {
        switch self {
        case .grok: return "Grok"
        case .opencode2: return "OpenCode 2"
        case .agy: return "Agy"
        }
    }
}

/// Calidad del resume de una tab de agente (TRD, modelo de sesión).
enum ResumeQuality: String, Codable {
    /// El id es fiable: se retoma ese hilo.
    case exact
    /// No hay id: se retoma el último de esa carpeta.
    case latestInDir
    /// Tab nueva, sin hilo previo.
    case fresh
}

/// Una tab de un proyecto. Shell o agente; el hilo lo posee el CLI del agente,
/// aquí solo vive el puntero.
struct Tab: Identifiable, Codable, Equatable {
    let id: UUID
    var projectId: UUID
    var kind: TabKind
    var cwd: String
    var title: String
    var agent: AgentKind?
    var sessionId: String?
    var resumeQuality: ResumeQuality

    init(
        id: UUID = UUID(),
        projectId: UUID,
        kind: TabKind,
        cwd: String,
        title: String,
        agent: AgentKind? = nil,
        sessionId: String? = nil,
        resumeQuality: ResumeQuality = .fresh
    ) {
        self.id = id
        self.projectId = projectId
        self.kind = kind
        self.cwd = cwd
        self.title = title
        self.agent = agent
        self.sessionId = sessionId
        self.resumeQuality = resumeQuality
    }
}
