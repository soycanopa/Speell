import Foundation

/// Preferencias de notificaciones (settings → Notificaciones). Todo encendido
/// por defecto; el ruido nativo solo suena si la ventana no está activa.
struct NotificationPreferences: Codable, Equatable {
    /// Llave maestra: sin ella, nada sale del app.
    var systemEnabled = true
    var agentMessages = true
    var finished = true
    var failed = true

    func isEnabled(_ kind: NoticeKind) -> Bool {
        switch kind {
        case .agentMessage: return agentMessages
        case .finished: return finished
        case .failed: return failed
        }
    }
}
