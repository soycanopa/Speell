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

            Divider()

            Button {
                model.onAddProject()
            } label: {
                Label("Añadir proyecto", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        // Detrás del contenido, para que el texto y las filas no se atenúen. El
        // `List` pinta su propio fondo, así que se pinta un rectángulo redondeado
        // opaco del color de la sidebar y encima la capa oscura.
        .background(SpeellPalette.corner.fill(Color(nsColor: .underPageBackgroundColor)))
        .background(SpeellPalette.sidebarDim)
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
