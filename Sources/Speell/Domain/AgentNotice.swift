import Foundation

/// Un aviso de una tab de agente. La fuente es siempre una señal real del
/// proceso — una notificación OSC del CLI, la campana del terminal o el fin
/// del comando — nunca heurística de scrollback (FLOW F4/F5).
enum AgentNotice: Equatable {
    /// El CLI mandó una notificación de escritorio (OSC 9/777): pidió
    /// permiso, terminó una tarea, lo que el agente diga.
    case agentMessage(title: String, body: String)
    /// El CLI pidió atención con la campana del terminal (BEL), sin mensaje.
    /// Solo es aviso en una tab de agente: una shell también toca la campana
    /// (`tput bel`) y eso no lo es.
    case bell
    /// El comando terminó. `-1` = el CLI no reportó código de salida.
    case commandFinished(exitCode: Int)

    var kind: NoticeKind {
        switch self {
        case .agentMessage: return .agentMessage
        case .bell: return .agentMessage
        case .commandFinished(let code): return code > 0 ? .failed : .finished
        }
    }
}

/// Los tipos de aviso que la configuración puede apagar o prender.
enum NoticeKind: String, Codable, CaseIterable {
    /// Mensajes del propio agente vía OSC (permisos, tarea lista…) o su
    /// campana de atención.
    case agentMessage
    /// El comando terminó sin error.
    case finished
    /// El comando terminó con código de error.
    case failed
}
