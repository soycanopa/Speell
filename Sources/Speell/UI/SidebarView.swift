import SwiftUI

/// Lista de proyectos y acción de añadir. Sección única, sin grupos.
struct SidebarView: View {
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach(model.projects) { project in
                    SidebarRow(
                        project: project,
                        missing: model.missingProjectIds.contains(project.id))
                        .tag(project.id)
                        // El estilo sidebar fija el leading de la celda en
                        // ~16 pt y `listRowInsets` no lo mueve; se compensa
                        // con padding negativo en el contenido. La selección
                        // sigue siendo la del sistema, a lo ancho de la fila.
                        .padding(.horizontal, -8)
                        .contextMenu {
                            Button("Quitar de la sidebar") {
                                model.onRemoveProject(project.id)
                            }
                        }
                }
            } header: {
                // El `+` vive en el encabezado, a la derecha del título —como
                // el de Finder—: añadir proyecto es una acción de la sección,
                // no del pie de la sidebar.
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
                .padding(.leading, 8)
                .padding(.trailing, 4)
                // Aire propio del título: contra la primera fila y contra el
                // borde de arriba de la sidebar.
                .padding(.vertical, 3)
                .padding(.bottom, 3)
            }
        }
        .listStyle(.sidebar)
        // El `List` pinta su propio fondo; sin esto el color de la sidebar no
        // llega a verse.
        .scrollContentBackground(.hidden)
        // La sidebar es la misma superficie que la ventana: un rectángulo del
        // mismo color, redondeado, y encima el contenido.
        .background(SpeellPalette.corner.fill(SpeellPalette.windowBackgroundColor))
        .clipShape(SpeellPalette.corner)
        // Hueco contra la terminal, por fuera del recorte: los 8 px quedan sin
        // fondo, que es justo la separación que se ve.
        .padding(.trailing, SpeellPalette.windowPadding)
        .frame(minWidth: 180, idealWidth: 240, maxWidth: 320)
    }

    private var selection: Binding<UUID?> {
        Binding(
            get: { model.activeProjectId },
            set: { newValue in
                if let id = newValue { model.onSelectProject(id) }
            })
    }
}
