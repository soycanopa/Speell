import SwiftUI

/// Lista de proyectos y acción de añadir. Sección única, sin grupos.
struct SidebarView: View {
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        // Sin `List`: la selección del estilo sidebar de sistema es un
        // material vibrante que sobre el fondo plano y opaco de Speell se
        // renderiza como un bloque degradado, y sus insets peleaban con el
        // chrome. Con pocas filas, una lista propia da el control y la calma
        // que la spec pide; las filas siguen siendo botones reales.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(model.projects) { project in
                    row(project)
                }
            }
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // La sidebar es la misma superficie que la ventana: un rectángulo del
        // mismo color, redondeado, y encima el contenido.
        .background(SpeellPalette.corner.fill(SpeellPalette.windowBackgroundColor))
        .clipShape(SpeellPalette.corner)
        // Hueco contra la terminal, por fuera del recorte: los 8 px quedan sin
        // fondo, que es justo la separación que se ve.
        .padding(.trailing, SpeellPalette.windowPadding)
        .frame(minWidth: 180, idealWidth: 240, maxWidth: 320)
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
    }

    /// Una fila de proyecto. La activa lleva un realce propio —redondeado,
    /// plano, blanco al 8%— en vez de la selección de sistema, que no sabe
    /// compositar sobre este chrome.
    private func row(_ project: Project) -> some View {
        let active = project.id == model.activeProjectId
        return Button {
            model.onSelectProject(project.id)
        } label: {
            SidebarRow(
                project: project,
                missing: model.missingProjectIds.contains(project.id))
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
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
        .buttonStyle(.plain)
        .contextMenu {
            Button("Quitar de la sidebar") {
                model.onRemoveProject(project.id)
            }
        }
    }
}
