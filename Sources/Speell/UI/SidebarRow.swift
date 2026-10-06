import SwiftUI

/// Fila de proyecto: nombre, path secundario truncado al medio, aviso si la
/// carpeta desapareció y punto si el proyecto tiene avisos sin mirar.
struct SidebarRow: View {
    let project: Project
    let missing: Bool
    var hasNotice: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(project.displayName)
                    .lineLimit(1)
                if missing {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .help("La carpeta ya no existe")
                }
                Spacer(minLength: 0)
                // El punto del proyecto (FLOW F4): igual al de la tab, en el
                // borde derecho para no mover el texto de las demás filas.
                if hasNotice {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(project.path)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 1)
    }
}
