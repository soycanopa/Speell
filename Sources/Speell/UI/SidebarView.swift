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
            // El `List` pinta su propio fondo opaco; sin esto el material de
            // abajo no llega a verse.
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
        // El material primero, el oscurecido encima de él: los dos van detrás del
        // contenido, así que el texto y las filas no se atenúan.
        .background(SpeellPalette.sidebarMaterial)
        .background(SpeellPalette.sidebarDim)
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
