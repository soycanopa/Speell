import SwiftUI

/// Contenido de la ventana: la surface de la tab activa, o la configuración.
/// Los tabs viven en el app bar, no aquí.
struct MainContentView: View {
    @ObservedObject var model: WorkspaceModel
    let pane: TerminalPane

    var body: some View {
        ZStack {
            if model.appMode == .settings {
                SettingsView(model: model)
            } else {
                TerminalPaneView(pane: pane)

                if model.activeProjectId == nil {
                    EmptyStateView(
                        kind: .noProject,
                        background: SpeellPalette.color(fromHex: model.terminalBackgroundHex),
                        onOpenFolder: { model.onAddProject() },
                        onNewTerminal: {})
                } else if model.tabs.isEmpty {
                    EmptyStateView(
                        kind: .noTabs,
                        background: SpeellPalette.color(fromHex: model.terminalBackgroundHex),
                        onOpenFolder: { model.onAddProject() },
                        onNewTerminal: { model.onNewTerminal() })
                }
            }
        }
        // El pane redondea solo abajo: arriba el app bar y la tab activa se
        // apoyan en ese borde, y una esquina redondeada abriría una cuña de
        // chrome justo donde la tab se une con la terminal — pero solo si la
        // tab activa es la primera. Si es otra, la esquina queda expuesta y
        // tiene que ir redondeada. En configuración no hay tab: las cuatro
        // esquinas van redondeadas.
        .clipShape(clipShape)
        .sheet(item: $model.sessionPicker) { request in
            SessionPickerView(model: model, agent: request.agent)
        }
    }

    /// La forma del pane según el modo y la tab activa.
    private var clipShape: UnevenRoundedRectangle {
        if model.appMode == .settings { return SpeellPalette.corner }
        let firstTabActive = model.tabs.first?.id == model.activeTabId
        return SpeellPalette.pane(roundTopLeading: !firstTabActive)
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
