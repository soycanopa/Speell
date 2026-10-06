import AppKit
import SwiftUI

/// Contenido de la ventana: la surface de la tab activa.
/// Los tabs viven en el app bar, no aquí.
struct MainContentView: View {
    @ObservedObject var model: WorkspaceModel
    let pane: TerminalPane

    var body: some View {
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
        // El pane redondea solo abajo: arriba el app bar y la tab activa se
        // apoyan en ese borde, y una esquina redondeada abriría una cuña de
        // chrome justo donde la tab se une con la terminal.
        .clipShape(SpeellPalette.pane)
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
