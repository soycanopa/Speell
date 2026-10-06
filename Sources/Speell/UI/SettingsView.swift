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
        case .agentes: AgentsSection(model: model)
        case .notificaciones: NotificationsSection(model: model)
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

    /// Tipografías monoespaciadas instaladas, medidas por avance de glifo.
    @State private var availableFonts: [String] = MonoFonts.installed()

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

/// Agentes: toggle de habilitación (el agente sale o entra en el menú del `+`)
/// y diagnóstico del binario en el PATH. Deshabilitar no toca las tabs
/// abiertas: solo deja de ofrecerlo.
private struct AgentsSection: View {
    @ObservedObject var model: WorkspaceModel

    @State private var diagnostics: [AgentKind: String?] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(AgentKind.allCases, id: \.self) { kind in
                row(kind)
                if kind != AgentKind.allCases.last {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .onAppear(perform: resolvePaths)
    }

    private func row(_ kind: AgentKind) -> some View {
        let enabled = model.agentPreferences.isEnabled(kind)
        return HStack(spacing: 10) {
            Circle()
                .fill(diagnosticColor(kind))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(enabled ? Color.primary : Color.secondary)
                Text(pathLabel(kind))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: binding(kind))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(enabled ? "Deshabilitar agente" : "Habilitar agente")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func binding(_ kind: AgentKind) -> Binding<Bool> {
        Binding(
            get: { model.agentPreferences.isEnabled(kind) },
            set: { model.onAgentToggle(kind, $0) })
    }

    /// Verde si el binario existe, rojo si no, gris mientras se resuelve.
    private func diagnosticColor(_ kind: AgentKind) -> Color {
        switch diagnostics[kind] {
        case .some(.some): return Color.green.opacity(0.8)
        case .some(.none): return Color.red.opacity(0.8)
        case .none: return Color.secondary.opacity(0.5)
        }
    }

    private func pathLabel(_ kind: AgentKind) -> String {
        switch diagnostics[kind] {
        case .some(.some(let path)): return path
        case .some(.none): return "no está en el PATH"
        case .none: return "buscando…"
        }
    }

    private func resolvePaths() {
        for kind in AgentKind.allCases where diagnostics[kind] == nil {
            let path = CLIProcess.run(
                executable: "/usr/bin/which",
                arguments: [kind.rawValue],
                cwd: NSHomeDirectory(),
                timeout: 2)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            diagnostics[kind] = path?.isEmpty == false ? path : nil
        }
    }
}

/// Diagnóstico de un binario de agente.
private struct AgentDiagnostic: Identifiable {
    let kind: AgentKind
    let path: String?

    var id: String { kind.rawValue }
}

/// Notificaciones: llave maestra del sistema y los tipos de aviso. El ruido
/// nativo solo suena si la ventana no está activa (FLOW F4); el punto de la
/// tab no depende de aquí.
private struct NotificationsSection: View {
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(
                title: "Notificaciones del sistema",
                detail: "Llave maestra: sin ella, nada sale del app.") {
                Toggle("", isOn: master).labelsHidden().toggleStyle(.switch)
            }

            Divider().padding(.leading, 14)

            row(
                title: "Mensajes del agente",
                detail: "El CLI avisó por su canal (permiso, tarea lista…).") {
                Toggle("", isOn: kind(.agentMessage)).labelsHidden().toggleStyle(.switch)
                    .disabled(!model.notificationPreferences.systemEnabled)
            }

            Divider().padding(.leading, 14)

            row(
                title: "El comando terminó",
                detail: "El proceso del agente terminó sin error.") {
                Toggle("", isOn: kind(.finished)).labelsHidden().toggleStyle(.switch)
                    .disabled(!model.notificationPreferences.systemEnabled)
            }

            Divider().padding(.leading, 14)

            row(
                title: "El comando falló",
                detail: "El proceso del agente terminó con código de error.") {
                Toggle("", isOn: kind(.failed)).labelsHidden().toggleStyle(.switch)
                    .disabled(!model.notificationPreferences.systemEnabled)
            }
        }
    }

    private var master: Binding<Bool> {
        Binding(
            get: { model.notificationPreferences.systemEnabled },
            set: { model.onNotificationPreferencesChange(
                NotificationPreferences(systemEnabled: $0,
                                        agentMessages: model.notificationPreferences.agentMessages,
                                        finished: model.notificationPreferences.finished,
                                        failed: model.notificationPreferences.failed)) })
    }

    private func kind(_ noticeKind: NoticeKind) -> Binding<Bool> {
        Binding(
            get: { model.notificationPreferences.isEnabled(noticeKind) },
            set: { model.onNotificationPreferencesChange(
                NotificationPreferences(systemEnabled: model.notificationPreferences.systemEnabled,
                                        agentMessages: noticeKind == .agentMessage ? $0 : model.notificationPreferences.agentMessages,
                                        finished: noticeKind == .finished ? $0 : model.notificationPreferences.finished,
                                        failed: noticeKind == .failed ? $0 : model.notificationPreferences.failed)) })
    }

    private func row<Control: View>(
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 24)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
