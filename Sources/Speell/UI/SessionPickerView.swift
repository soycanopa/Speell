import SwiftUI

/// Modal de sesiones de un agente para la carpeta del proyecto activo.
/// Lista lo que el CLI ya guarda; Speell no copia nada.
struct SessionPickerView: View {
    @ObservedObject var model: WorkspaceModel
    let agent: AgentKind

    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sesiones de \(agent.displayName)")
                .font(.system(size: 13, weight: .semibold))
                .padding(12)
            Divider()

            content

            Divider()
            HStack(spacing: 8) {
                Spacer()
                Button("Cancelar") {
                    model.onCancelSessionPicker()
                }
                .keyboardShortcut(.cancelAction)

                Button("Abrir sesión") {
                    open()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil)
            }
            .padding(12)
        }
        .frame(width: 540, height: 380)
    }

    @ViewBuilder
    private var content: some View {
        if model.loadingSessions {
            note("Buscando sesiones…")
        } else if model.agentSessions.isEmpty {
            VStack(spacing: 10) {
                Text("No hay sesiones de \(agent.displayName) en esta carpeta.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button("Sesión nueva") {
                    model.onNewAgentTab(agent, .fresh)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(model.agentSessions, id: \.id, selection: $selected) { session in
                HStack(spacing: 8) {
                    Text(session.title)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(String(session.id.prefix(8)))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .tag(session.id)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    selected = session.id
                    open()
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func open() {
        guard let id = selected,
              let session = model.agentSessions.first(where: { $0.id == id }) else { return }
        model.onNewAgentTab(agent, .session(session))
    }
}
