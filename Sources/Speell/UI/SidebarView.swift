import SwiftUI

/// Sidebar: los proyectos del workspace, o las secciones de la configuración.
/// Abajo, el footer lleva el engranaje que alterna el modo.
struct SidebarView: View {
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sin `List`: la selección del estilo sidebar de sistema es un
            // material vibrante que sobre el fondo plano y opaco de Speell se
            // renderiza como un bloque degradado, y sus insets peleaban con el
            // chrome. Con pocas filas, una lista propia da el control y la calma
            // que la spec pide; las filas siguen siendo botones reales.
            //
            // El `GeometryReader` es obligatorio: un `ScrollView` vertical no
            // propone ancho a su contenido y el `VStack` se abrazaba al texto —
            // el realce y el `+` quedaban cortos y el hueco derecho crecía con el
            // ancho de la sidebar.
            GeometryReader { geo in
                // Sin indicadores: un `ScrollView` de macOS con scroller visible
                // reserva ~17 pt de ancho para él aunque no haya nada que
                // scrollear, y el contenido (realce, `+`) quedaba corto del borde
                // derecho por exactamente eso.
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        switch model.appMode {
                        case .workspace:
                            header
                            ForEach(model.projects) { project in
                                projectRow(project)
                            }
                        case .settings:
                            settingsHeader
                            ForEach(SettingsSection.allCases) { section in
                                sectionRow(section)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .frame(width: geo.size.width, alignment: .leading)
                }
            }

            footer
        }
        // La sidebar es la misma superficie que la ventana: un rectángulo del
        // mismo color, redondeado, y encima el contenido.
        .background(SpeellPalette.sidebarPane.fill(SpeellPalette.windowBackgroundColor))
        .clipShape(SpeellPalette.sidebarPane)
        // Hueco contra la terminal, por fuera del recorte. Se descuenta el
        // ancho del divisor del split para que el canal visible mida 8 como
        // los márgenes de la ventana, no 13.
        .padding(.trailing, SpeellPalette.windowPadding - SpeellPalette.splitDividerAllowance)
        .frame(minWidth: 180, idealWidth: 240, maxWidth: 320)
    }

    /// Footer del sidebar: el engranaje de la configuración, siempre abajo.
    private var footer: some View {
        HStack {
            Button {
                model.appMode = model.appMode == .settings ? .workspace : .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(model.appMode == .settings ? Color.primary : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background {
                        if model.appMode == .settings {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(model.appMode == .settings ? "Volver al workspace" : "Configuración")
            Spacer()
        }
        .padding(.leading, 8)
        .padding(.vertical, 5)
    }

    /// Encabezado de la sección. El `+` vive aquí, a la derecha del título
    /// —como el de Finder—: añadir proyecto es una acción de la sección.
    private var header: some View {
        HStack {
            Text("Proyectos")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.onAddProject()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Añadir proyecto")
        }
        .padding(.leading, 10)
        .padding(.trailing, 2)
        .padding(.bottom, 6)
        // Llenar el ancho del VStack: sin esto, el HStack se queda en su ancho
        // ideal y el `+` no llega al borde derecho.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingsHeader: some View {
        Text("Configuración")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 10)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Una fila de proyecto. La activa lleva un realce propio —redondeado,
    /// plano, blanco al 8%— en vez de la selección de sistema, que no sabe
    /// compositar sobre este chrome.
    private func projectRow(_ project: Project) -> some View {
        let active = project.id == model.activeProjectId
        return Button {
            model.onSelectProject(project.id)
        } label: {
            SidebarRow(
                project: project,
                missing: model.missingProjectIds.contains(project.id))
                .rowChrome(active: active)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Quitar de la sidebar") {
                model.onRemoveProject(project.id)
            }
        }
    }

    /// Una fila de sección de configuración, con el mismo realce de selección
    /// y un poco más de aire que las filas de proyecto: que respiren.
    private func sectionRow(_ section: SettingsSection) -> some View {
        let active = section == model.settingsSection
        return Button {
            model.settingsSection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(section.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
            .rowChrome(active: active, verticalPadding: 8)
        }
        .buttonStyle(.plain)
    }
}

/// Realce y aire de fila de la sidebar, compartido por proyectos y secciones.
private extension View {
    func rowChrome(active: Bool, verticalPadding: CGFloat = 5) -> some View {
        self
            .padding(.horizontal, 6)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .padding(.horizontal, 2)
                }
            }
            .contentShape(Rectangle())
    }
}
