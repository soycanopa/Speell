import SwiftUI

/// Menú del `+`: terminal y un desplegable por agente. Vive en un popover
/// anclado al botón y no abre ningún modal: agente e hilos se resuelven dentro.
struct TabMenuView: View {
    @ObservedObject var model: WorkspaceModel
    /// Cierra el popover cuando ya se eligió algo.
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch model.menuPage {
            case .root:
                root
            case .agent(let agent):
                agentOptions(agent)
            case .sessions(let agent):
                agentSessions(agent)
            }
        }
        .frame(width: 280)
        .padding(.vertical, 4)
    }

    /// Terminal y un desplegable por agente implementado.
    private var root: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow(title: "Nueva terminal", systemImage: "terminal") {
                model.onNewTerminal()
                dismiss()
            }

            if !model.availableAgents.isEmpty {
                Divider().padding(.vertical, 5)
                MenuSection(title: "Agentes")
                ForEach(model.availableAgents, id: \.self) { agent in
                    MenuRow(
                        title: agent.displayName,
                        systemImage: "sparkles",
                        trailing: "chevron.right"
                    ) {
                        model.onOpenAgentMenu(agent)
                    }
                }
            }
        }
    }

    private func agentOptions(_ agent: AgentKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow(title: "Nueva tab", systemImage: "chevron.left") {
                model.onTabMenuBack()
            }
            Divider().padding(.vertical, 5)

            MenuSection(title: agent.displayName)
            MenuRow(title: "Hilo nuevo", systemImage: "plus.circle") {
                model.onNewAgentTab(agent, .fresh)
                dismiss()
            }
            MenuRow(title: "Último de esta carpeta", systemImage: "clock.arrow.circlepath") {
                model.onNewAgentTab(agent, .latest)
                dismiss()
            }
            MenuRow(title: "Elegir hilo…", systemImage: "list.bullet") {
                model.onLoadAgentSessions(agent)
            }
        }
    }

    private func agentSessions(_ agent: AgentKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow(title: agent.displayName, systemImage: "chevron.left") {
                model.onTabMenuBack()
            }
            Divider().padding(.vertical, 5)

            if model.loadingSessions {
                MenuNote("Buscando hilos…")
            } else if model.agentSessions.isEmpty {
                MenuNote("No hay hilos de \(agent.displayName) en esta carpeta.")
            } else {
                ForEach(model.agentSessions, id: \.id) { reference in
                    MenuRow(
                        title: reference.title,
                        systemImage: nil,
                        subtitle: String(reference.id.prefix(8))
                    ) {
                        model.onNewAgentTab(agent, .session(reference))
                        dismiss()
                    }
                }
            }

            Divider().padding(.vertical, 5)
            MenuRow(title: "Hilo nuevo", systemImage: "plus.circle") {
                model.onNewAgentTab(agent, .fresh)
                dismiss()
            }
        }
    }
}

private struct MenuSection: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.bottom, 1)
    }
}

private struct MenuNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MenuRow: View {
    let title: String
    var systemImage: String?
    var subtitle: String?
    var trailing: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11))
                        .frame(width: 14)
                }
                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                if let subtitle {
                    Spacer(minLength: 8)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                if let trailing {
                    Spacer(minLength: 8)
                    Image(systemName: trailing)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(hovering ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
