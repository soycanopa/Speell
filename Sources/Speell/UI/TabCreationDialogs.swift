import AppKit

/// Diálogos de creación de tab. Preguntan; no deciden comandos.
@MainActor
enum TabCreationDialogs {
    enum TabKindChoice {
        case terminal
        case agent
    }

    enum AgentChoice {
        case fresh
        case latest
        case session(SessionRef)
    }

    /// `+` pregunta shell o agente (UX, Tabs).
    static func askTabKind() -> TabKindChoice? {
        let alert = NSAlert()
        alert.messageText = "Nueva tab"
        alert.informativeText = "¿Terminal o agente?"
        alert.addButton(withTitle: "Terminal")
        alert.addButton(withTitle: "Agente")
        alert.addButton(withTitle: "Cancelar")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .terminal
        case .alertSecondButtonReturn: return .agent
        default: return nil
        }
    }

    /// Hilos del agente en esta carpeta. Sin lista, solo nuevo o último.
    static func askAgentSession(agentName: String, sessions: [SessionRef]) -> AgentChoice? {
        guard !sessions.isEmpty else {
            let alert = NSAlert()
            alert.messageText = agentName
            alert.informativeText = "No hay hilos en esta carpeta."
            alert.addButton(withTitle: "Hilo nuevo")
            alert.addButton(withTitle: "Último de esta carpeta")
            alert.addButton(withTitle: "Cancelar")
            switch alert.runModal() {
            case .alertFirstButtonReturn: return .fresh
            case .alertSecondButtonReturn: return .latest
            default: return nil
            }
        }

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 460, height: 25))
        for session in sessions {
            popup.addItem(withTitle: "\(session.id.prefix(8))  \(session.title)")
        }

        let alert = NSAlert()
        alert.messageText = agentName
        alert.informativeText = "Hilo de esta carpeta."
        alert.accessoryView = popup
        alert.addButton(withTitle: "Abrir hilo")
        alert.addButton(withTitle: "Hilo nuevo")
        alert.addButton(withTitle: "Último de esta carpeta")
        alert.addButton(withTitle: "Cancelar")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let index = popup.indexOfSelectedItem
            guard sessions.indices.contains(index) else { return nil }
            return .session(sessions[index])
        case .alertSecondButtonReturn:
            return .fresh
        case .alertThirdButtonReturn:
            return .latest
        default:
            return nil
        }
    }
}
