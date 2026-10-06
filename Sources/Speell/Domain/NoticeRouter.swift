import Foundation

/// Qué hace un aviso: punto en la tab y/o notificación nativa. Es la parte
/// de la decisión de FLOW F4, pura y sin AppKit: el que la llama aplica el
/// resultado (insertar en `noticedTabIds`, pedir la notificación).
struct NoticeRoute: Equatable {
    /// La tab prende su punto; se limpia al seleccionarla.
    var marksTab: Bool
    /// Sale una notificación nativa del sistema.
    var postsSystemNotification: Bool
}

enum NoticeRouter {
    /// La campana no es aviso fuera de una tab de agente: cualquier proceso
    /// puede tocarla y una shell que la toque no tiene nada que mirar.
    /// El punto siempre que la señal cuente; la notificación nativa exige,
    /// además, sistema disponible, llave maestra, tipo encendido y Speell
    /// sin foco — el ruido nativo solo tiene sentido cuando no estás mirando.
    static func route(
        _ notice: AgentNotice,
        isAgentTab: Bool,
        appActive: Bool,
        preferences: NotificationPreferences,
        systemAvailable: Bool
    ) -> NoticeRoute {
        if case .bell = notice, !isAgentTab {
            return NoticeRoute(marksTab: false, postsSystemNotification: false)
        }
        return NoticeRoute(
            marksTab: true,
            postsSystemNotification: systemAvailable
                && preferences.systemEnabled
                && preferences.isEnabled(notice.kind)
                && !appActive)
    }
}
