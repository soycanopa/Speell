import Foundation

/// El canal de avisos que cada CLI ofrece de verdad, verificado contra su
/// fuente primaria (docs/decisions/0006). La configuración lo muestra tal
/// cual: nada promete un canal que el binario no tiene (FLOW F5, DoD
/// "aviso real o hooks: none explícito por agente").
enum NoticeSource: String {
    /// El CLI emite notificaciones OSC 9/777: Grok, con su `[ui.notifications]`
    /// (manual embebido del binario; Ghostty → OSC 777 en su matriz).
    case osc
    /// El CLI toca la campana del terminal (BEL) al terminar una tarea o
    /// pedir atención: Agy, con `notifications: true` en sus settings
    /// (docs de Antigravity). Speell la atrapa como `GHOSTTY_ACTION_RING_BELL`.
    case bell
    /// Sin canal documentado en v1: OpenCode 2. Su plugin TS
    /// (`permission.hook("evaluate")` + `event.subscribe()`) queda en backlog.
    case none
}
