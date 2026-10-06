import SwiftUI

/// Panel de configuración: las opciones de la sección elegida en la sidebar,
/// sin tabs. Las surfaces siguen vivas debajo; al salir de settings el
/// workspace vuelve exacto.
struct SettingsView: View {
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.settingsSection.title)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)
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

/// Apariencia: fondo, tipografía y tamaño de la terminal. Se persiste en el
/// override de libghostty y se aplica en vivo a las surfaces abiertas.
private struct AppearanceSection: View {
    @ObservedObject var model: WorkspaceModel

    @State private var color: Color
    @State private var fontFamily: String?
    @State private var fontSize: Double

    init(model: WorkspaceModel) {
        self.model = model
        let directory = TerminalPalette.applicationSupportDirectory
        _color = State(initialValue: SpeellPalette.color(
            fromHex: TerminalPalette.backgroundHex(in: directory)))
        _fontFamily = State(initialValue: TerminalPalette.fontFamily(in: directory))
        _fontSize = State(initialValue: TerminalPalette.fontSize(in: directory))
    }

    /// Tipografías monoespaciadas conocidas, filtradas por las instaladas.
    /// La terminal no pide cualquier fuente: pide mono.
    private static let monoFonts = [
        "JetBrains Mono", "Fira Code", "Hack", "SF Mono", "Menlo", "Monaco",
        "Source Code Pro", "Inconsolata", "IBM Plex Mono", "Cascadia Code",
        "Andale Mono", "Courier New",
    ]

    /// Las instaladas de la lista curada, alfabéticas.
    private var availableFonts: [String] {
        let installed = Set(NSFontManager.shared.availableFonts)
        return Self.monoFonts.filter { installed.contains($0) }.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fondo de la terminal")
                        .font(.system(size: 13))
                    Text("Se aplica en vivo a las tabs abiertas y a las nuevas.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } control: {
                ColorPicker("", selection: $color, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: color) { newColor in
                        emit()
                    }
            }

            Divider().padding(.leading, 14)

            row {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tipografía")
                        .font(.system(size: 13))
                    Text("Solo monoespaciadas instaladas. Sin elegir, la que trae ghostty.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } control: {
                Picker("", selection: $fontFamily) {
                    Text("Por defecto").tag(String?.none)
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(String?.some(font))
                    }
                }
                .labelsHidden()
                .frame(width: 190)
                .onChange(of: fontFamily) { _ in
                    emit()
                }
            }

            Divider().padding(.leading, 14)

            row {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tamaño")
                        .font(.system(size: 13))
                    Text("El default del pin es 13 en macOS.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } control: {
                Stepper(value: $fontSize, in: 7...28, step: 1) {
                    Text("\(Int(fontSize)) pt")
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .frame(minWidth: 46, alignment: .trailing)
                }
                .fixedSize()
                .onChange(of: fontSize) { _ in
                    emit()
                }
            }
        }
    }

    /// Cambia el aire de una fila: las opciones respiran.
    private func row<Label: View, Control: View>(
        @ViewBuilder label: () -> Label,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack {
            label()
            Spacer(minLength: 24)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func emit() {
        model.onAppearanceChange(
            SpeellPalette.hex(from: NSColor(color)),
            fontFamily,
            fontSize)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
