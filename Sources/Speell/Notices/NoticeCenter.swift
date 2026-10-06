import AppKit
import UserNotifications

/// Entrega avisos como notificaciones nativas del sistema.
///
/// `UNUserNotificationCenter` exige app empaquetada (CFBundleIdentifier): sin
/// bundle el centro queda deshabilitado y el aviso vive solo como punto en la
/// tab. Usar `Scripts/make-app.sh` para el flujo con notificaciones.
/// El permiso se pide en el primer aviso (FLOW F4).
@MainActor
final class NoticeCenter: NSObject {
    /// Tab a poner al frente cuando el usuario hace click en la notificación.
    private let onActivate: (UUID) -> Void
    private var authorizationRequested = false

    init(onActivate: @escaping (UUID) -> Void) {
        self.onActivate = onActivate
        super.init()
        if let center = Self.center {
            center.delegate = self
        }
    }

    private static var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    var isAvailable: Bool { Self.center != nil }

    /// Publica el aviso. Devuelve `false` si no pudo (sin bundle): el que
    /// llama decide qué queda visible (el punto de la tab, por ejemplo).
    @discardableResult
    func post(_ notice: AgentNotice, tabId: UUID, tabTitle: String) -> Bool {
        guard let center = Self.center else { return false }
        requestAuthorizationIfNeeded(center)

        let content = UNMutableNotificationContent()
        content.title = tabTitle
        switch notice {
        case .agentMessage(_, let body):
            content.body = body
        case .bell:
            content.body = "El agente terminó una tarea o pide tu atención."
        case .commandFinished(0):
            content.body = "El comando terminó."
        case .commandFinished(let code):
            content.body = "El comando terminó con error \(code)."
        }
        let request = UNNotificationRequest(
            identifier: tabId.uuidString,
            content: content,
            trigger: nil)
        center.add(request)
        return true
    }

    private func requestAuthorizationIfNeeded(_ center: UNUserNotificationCenter) {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

extension NoticeCenter: UNUserNotificationCenterDelegate {
    /// La app en primer plano no duplica el ruido: el aviso nativo solo
    /// tiene sentido cuando Speell no está activo (FLOW F4).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        Task { @MainActor in
            guard let tabId = UUID(uuidString: identifier) else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.onActivate(tabId)
            completionHandler()
        }
    }
}
