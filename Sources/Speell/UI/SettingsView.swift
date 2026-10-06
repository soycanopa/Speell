import SwiftUI

/// Panel de configuración: las opciones de la sección elegida en la sidebar,
/// sin tabs. Las surfaces siguen vivas debajo; al salir de settings el
/// workspace vuelve exacto.
struct SettingsView: View {
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.settingsSection.title)
                .font(.system(size: 13, weight: .semibold))
                .padding(12)
            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // El área de settings es la misma superficie que la terminal: mismo
        // fondo vigente, para que el pane no cambie de tono al entrar.
        .background(SpeellPalette.color(fromHex: model.terminalBackgroundHex))
    }

    @ViewBuilder
    private var content: some View {
        switch model.settingsSection {
        case .apariencia: AppearanceSection(model: model)
        case .agentes: AgentsSection()
        }
    }
}

/// Apariencia: el fondo de la terminal. Se persiste en el override de
/// libghostty y se aplica en vivo a las surfaces abiertas.
private struct AppearanceSection: View {
    @ObservedObject var model: WorkspaceModel

    @State private var color: Color

    init(model: WorkspaceModel) {
        self.model = model
        let hex = TerminalPalette.backgroundHex(in: TerminalPalette.applicationSupportDirectory)
        _color = State(initialValue: SpeellPalette.color(fromHex: hex))
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fondo de la terminal")
                    .font(.system(size: 13))
                Text("Se aplica en vivo a las tabs abiertas y a las nuevas.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: color) { newColor in
                    model.onBackgroundChange(SpeellPalette.hex(from: NSColor(newColor)))
                }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Agentes: qué binarios del PATH encuentra Speell y dónde. Diagnóstico de
/// lectura; sin controles por ahora.
private struct AgentsSection: View {
    @State private var diagnostics: [AgentDiagnostic] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if diagnostics.isEmpty {
                Text("Buscando binarios…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
            ForEach(diagnostics) { diagnostic in
                row(diagnostic)
                Divider().padding(.leading, 12)
            }
        }
        .onAppear(perform: load)
    }

    private func row(_ diagnostic: AgentDiagnostic) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(diagnostic.path == nil ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                .frame(width: 7, height: 7)
            Text(diagnostic.kind.displayName)
                .font(.system(size: 13))
            Spacer(minLength: 12)
            Text(diagnostic.path ?? "no está en el PATH")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
    }

    private func load() {
        diagnostics = AgentKind.allCases.map { kind in
            let path = CLIProcess.run(
                executable: "/usr/bin/which",
                arguments: [kind.rawValue],
                cwd: NSHomeDirectory(),
                timeout: 2)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return AgentDiagnostic(
                kind: kind,
                path: path?.isEmpty == false ? path : nil)
        }
    }
}

/// Diagnóstico de un binario de agente.
private struct AgentDiagnostic: Identifiable {
    let kind: AgentKind
    let path: String?

    var id: String { kind.rawValue }
}
