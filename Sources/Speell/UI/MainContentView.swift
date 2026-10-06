import AppKit
import SwiftUI

/// Contenido de la ventana: barra de tabs y surface de la tab activa.
/// El vacío se pinta encima del pane para no desmontar las surfaces vivas.
struct MainContentView: View {
    @ObservedObject var model: WorkspaceModel
    let pane: TerminalPane

    var body: some View {
        VStack(spacing: 0) {
            if model.activeProjectId != nil {
                TabBarView(model: model)
            }

            ZStack {
                TerminalPaneView(pane: pane)

                if model.activeProjectId == nil {
                    EmptyStateView(
                        kind: .noProject,
                        onOpenFolder: { model.onAddProject() },
                        onNewTerminal: {})
                } else if model.tabs.isEmpty {
                    EmptyStateView(
                        kind: .noTabs,
                        onOpenFolder: { model.onAddProject() },
                        onNewTerminal: { model.onNewTerminal() })
                }
            }
        }
        .sheet(item: $model.sessionPicker) { request in
            SessionPickerView(model: model, agent: request.agent)
        }
    }
}

/// Hospeda el `TerminalPane` (AppKit) dentro del árbol SwiftUI.
struct TerminalPaneView: NSViewRepresentable {
    let pane: TerminalPane

    func makeNSView(context: Context) -> TerminalPane {
        pane
    }

    func updateNSView(_ nsView: TerminalPane, context: Context) {}
}
