import Foundation

/// Contrato mínimo de un agente de terminal. Nada de protocolo de chat.
/// El adaptador habla con el CLI; no sabe qué vista lo muestra.
protocol AgentAdapter {
    var kind: AgentKind { get }

    /// Si el CLI acepta fijar el id de una sesión nueva. Cuando es falso, una
    /// tab nueva nace sin puntero (`resumeQuality: .fresh`): fijar un id que
    /// el CLI no registra haría fallar el resume (FLOW F6).
    var canPinSessionId: Bool { get }

    /// Hilos que el CLI conoce para esa carpeta. Vacío si no hay lista.
    func list(cwd: String) async -> [SessionRef]

    /// Sesión nueva. Speell propone el id y el CLI lo respeta, así que la tab
    /// nace en calidad `exact` sin adivinar nada (ver docs/decisions/0003).
    func launch(cwd: String, sessionId: String) -> Command

    /// Retoma ese hilo concreto.
    func resume(cwd: String, id: String) -> Command

    /// Retoma el último hilo de esa carpeta.
    func continueLatest(cwd: String) -> Command
}
