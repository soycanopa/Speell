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
