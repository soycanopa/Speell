import SwiftUI

/// Menú del `+`: terminal y los agentes que tengan adaptador. Vive en un
/// popover anclado al botón; la lista de hilos se resuelve dentro del mismo
/// popover, sin modal de por medio.
struct TabMenuView: View {
    @ObservedObject var model: WorkspaceModel
    /// Cierra el popover cuando ya se eligió algo.
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let agent = model.sessionListAgent {
                sessionList(for: agent)
            } else {
                mainMenu
            }
        }
        .frame(width: 280)
        .padding(.vertical, 4)
    }

    private var mainMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow(title: "Nueva terminal", systemImage: "terminal") {
                model.onNewTerminal()
                dismiss()
            }

            ForEach(model.availableAgents, id: \.self) { agent in
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
    }

    private func sessionList(for agent: AgentKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow(title: agent.displayName, systemImage: "chevron.left") {
                model.onCloseAgentSessions()
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
