import SwiftUI

/// Fila de proyecto: nombre, path secundario truncado al medio y aviso si la
/// carpeta desapareció.
struct SidebarRow: View {
    let project: Project
    let missing: Bool

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
            }
            Text(project.path)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 1)
    }
}
