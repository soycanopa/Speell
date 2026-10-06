import SwiftUI

/// Vacío: el home que recibe cuando no hay terminal abierta. Cuatro tarjetas
/// de acción en dos columnas sobre el mismo tono de la terminal — agente,
/// terminal, proyecto y móvil, que llega después. Sin ilustraciones de
/// onboarding.
struct EmptyStateView: View {
    enum Kind {
        case noProject
        case noTabs
    }

    let kind: Kind
    let background: Color
    @ObservedObject var model: WorkspaceModel

    @State private var showingAgentMenu = false

    /// Lanzar terminal o agente exige un proyecto activo: sin él las tarjetas
    /// quedan apagadas y el camino es crear el proyecto.
    private var launchesEnabled: Bool { kind == .noTabs }

    var body: some View {
        // Dos columnas: agente/terminal arriba, proyecto/móvil abajo.
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                agentCard
                EmptyStateCard(
                    title: "Nueva terminal",
                    systemImage: "terminal",
                    enabled: launchesEnabled,
                    action: { model.onNewTerminal() })
            }
            HStack(spacing: 14) {
                EmptyStateCard(
                    title: "Nuevo proyecto",
                    systemImage: "folder.badge.plus",
                    enabled: true,
                    action: { model.onAddProject() })
                EmptyStateCard(
                    title: "Conectar móvil",
                    systemImage: "iphone.radiowaves.left.and.right",
                    caption: "Pronto",
                    enabled: false,
                    action: {})
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // El mismo tono que la terminal: el vacío ocupa el lugar de la surface
        // y no se tiene que notar el cambio cuando aparece o desaparece.
        .background(background)
    }

    /// Nuevo agente: el mismo menú del `+` (elige sesión incluida), sin la
    /// fila de terminal que aquí tiene su propia tarjeta.
    private var agentCard: some View {
        EmptyStateCard(
            title: "Nuevo agente",
            systemImage: "cpu",
            enabled: launchesEnabled,
            action: { showingAgentMenu = true })
            .popover(isPresented: $showingAgentMenu, arrowEdge: .bottom) {
                TabMenuView(model: model, dismiss: {
                    showingAgentMenu = false
                }, showsTerminalRow: false)
            }
    }
}

/// Una tarjeta del home: icono arriba, título abajo, fondo que se enciende al
/// pasar el cursor. Apagada no reacciona y baja su peso.
private struct EmptyStateCard: View {
    let title: String
    let systemImage: String
    var caption: String?
    let enabled: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(enabled && hovering ? Color.primary : Color.secondary)
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(enabled ? Color.primary : Color.secondary)
                    if let caption {
                        Text(caption)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(minWidth: 172, minHeight: 112)
            .background {
                RoundedRectangle(cornerRadius: SpeellPalette.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(fillOpacity))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = enabled && $0 }
        .opacity(enabled ? 1 : 0.55)
    }

    private var fillOpacity: CGFloat {
        guard enabled else { return 0.04 }
        return hovering ? 0.10 : 0.06
    }
}
