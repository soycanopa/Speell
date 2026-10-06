import SwiftUI

/// Menú del `+`: terminal y una fila por agente con sus acciones como iconos.
/// Vive en un popover anclado al botón; elegir sesión abre un modal aparte.
struct TabMenuView: View {
    @ObservedObject var model: WorkspaceModel
    /// Cierra el popover cuando ya se eligió algo.
    var dismiss: () -> Void

    var body: some View {
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
                        agent: agent,
                        onNew: {
                            model.onNewAgentTab(agent, .fresh)
                            dismiss()
                        },
                        onLatest: {
                            model.onNewAgentTab(agent, .latest)
                            dismiss()
                        },
                        onChoose: {
                            dismiss()
                            model.onPickAgentSession(agent)
                        })
                }
            }
        }
        .frame(width: 232)
        .padding(.vertical, 4)
    }
}

/// Fila de agente: icono y nombre, con las tres acciones al lado.
private struct AgentRow: View {
    let agent: AgentKind
    let onNew: () -> Void
    let onLatest: () -> Void
    let onChoose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: 14, height: 14)
            Text(agent.displayName)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer(minLength: 10)
            IconButton(systemImage: "plus.circle", help: "Sesión nueva", action: onNew)
            IconButton(systemImage: "clock.arrow.circlepath", help: "Última sesión de esta carpeta", action: onLatest)
            IconButton(systemImage: "list.bullet", help: "Elegir sesión…", action: onChoose)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var icon: some View {
        if let image = AgentIcon.image(for: agent) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
        }
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

private struct MenuRow: View {
    let title: String
    var systemImage: String?
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
