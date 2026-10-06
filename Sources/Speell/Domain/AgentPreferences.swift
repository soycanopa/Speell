import Foundation

/// Preferencias de agentes persistidas: qué agentes quiere el usuario
/// habilitados. Un agente ausente está habilitado (el default es todos).
/// Deshabilitar un agente solo lo saca del menú del `+`: sus tabs abiertas
/// no se tocan.
struct AgentPreferences: Codable, Equatable {
    private var enabledByAgent: [String: Bool] = [:]

    func isEnabled(_ agent: AgentKind) -> Bool {
        enabledByAgent[agent.rawValue] ?? true
    }

    mutating func setEnabled(_ enabled: Bool, for agent: AgentKind) {
        enabledByAgent[agent.rawValue] = enabled
    }
}
