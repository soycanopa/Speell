import SwiftUI

/// Vacío: una acción, sin ilustraciones de onboarding.
struct EmptyStateView: View {
    enum Kind {
        case noProject
        case noTabs
    }

    let kind: Kind
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
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
