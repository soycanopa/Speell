import Foundation

/// Contrato mínimo de un agente de terminal. Nada de protocolo de chat.
/// El adaptador habla con el CLI; no sabe qué vista lo muestra.
protocol AgentAdapter {
    var kind: AgentKind { get }

    /// El canal de avisos real de este CLI, verificado contra su fuente
    /// primaria (docs/decisions/0006). La UI lo declara; nada lo inventa.
    var noticeSource: NoticeSource { get }

    /// Hilos que el CLI conoce para esa carpeta. Vacío si no hay lista.
    func list(cwd: String) async -> [SessionRef]

    /// Conversación nueva, sin id: el id lo genera y guarda el propio CLI
    /// (docs/decisions/0005). Speell no propone ids.
    func launch(cwd: String) -> Command

    /// Retoma ese hilo concreto, con un id que salió de `list`.
    func resume(cwd: String, id: String) -> Command

    /// Retoma el último hilo de esa carpeta.
    func continueLatest(cwd: String) -> Command
}
