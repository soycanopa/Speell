import SwiftUI

/// Vacío: una acción, sin ilustraciones de onboarding.
struct EmptyStateView: View {
    enum Kind {
        case noProject
        case noTabs
    }

    let kind: Kind
    let background: Color
    var onOpenFolder: () -> Void
    var onNewTerminal: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            switch kind {
            case .noProject:
                Button("Abrir carpeta", action: onOpenFolder)
            case .noTabs:
                Button("Nueva terminal", action: onNewTerminal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // El mismo tono que la terminal: el vacío ocupa el lugar de la surface
        // y no se tiene que notar el cambio cuando aparece o desaparece.
        .background(background)
    }
}
