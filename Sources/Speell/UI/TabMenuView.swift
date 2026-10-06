import SwiftUI

/// Menú del `+`: terminal y una fila por agente con sus acciones como iconos.
/// Vive en un popover anclado al botón y no abre ningún modal: la lista de
/// hilos se resuelve dentro del mismo popover.
struct TabMenuView: View {
    @ObservedObject var model: WorkspaceModel
    /// Cierra el popover cuando ya se eligió algo.
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch model.menuPage {
            case .root:
                root
            case .sessions(let agent):
                agentSessions(agent)
            }
        }
        .frame(width: 268)
        .padding(.vertical, 4)
    }

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
                    AgentRow(
                        name: agent.displayName,
                        onNew: {
                            model.onNewAgentTab(agent, .fresh)
                            dismiss()
                        },
                        onLatest: {
                            model.onNewAgentTab(agent, .latest)
                            dismiss()
                        },
                        onChoose: { model.onLoadAgentSessions(agent) })
                }
            }
        }
    }

    private func agentSessions(_ agent: AgentKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow(title: "Nueva tab", systemImage: "chevron.left") {
                model.onTabMenuBack()
            }
            Divider().padding(.vertical, 5)
            MenuSection(title: agent.displayName)

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
        }
    }
}

/// Fila de agente: nombre y las tres acciones como iconos.
private struct AgentRow: View {
    let name: String
    let onNew: () -> Void
    let onLatest: () -> Void
    let onChoose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .frame(width: 14)
            Text(name)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer(minLength: 10)
            IconButton(systemImage: "plus.circle", help: "Hilo nuevo", action: onNew)
            IconButton(systemImage: "clock.arrow.circlepath", help: "Último de esta carpeta", action: onLatest)
            IconButton(systemImage: "list.bullet", help: "Elegir hilo…", action: onChoose)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }
}

private struct IconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
                .background(hovering ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
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
