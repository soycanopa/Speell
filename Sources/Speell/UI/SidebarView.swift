import SwiftUI

/// Lista de proyectos y acción de añadir. Sección única, sin grupos.
struct SidebarView: View {
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selection) {
                Section("Proyectos") {
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
                }
            }
            .listStyle(.sidebar)
            // El `List` pinta su propio fondo; sin esto el oscurecido de abajo
            // no llega a verse.
            .scrollContentBackground(.hidden)

            // Solo el icono, sin línea encima: el `Divider` se leía como un
            // borde del botón y el texto sobraba junto al `+` de la tab bar.
            // El label estira a todo el ancho para que el click no exija dar
            // en el glifo.
            Button {
                model.onAddProject()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Añadir proyecto")
            .padding(8)
        }
        // La sidebar es la misma superficie que la ventana: un rectángulo del
        // mismo color, redondeado, y encima el contenido. El `List` pinta su
        // propio fondo, así que hay que taparlo con este rectángulo opaco.
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
