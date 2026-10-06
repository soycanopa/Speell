import SwiftUI

/// Una tab: título y botón de cerrar al hover o si está activa.
/// El punto de estado llega con los avisos (fase 4).
struct TabItem: View {
    let tab: Tab
    let active: Bool
    var onSelect: () -> Void
    var onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(tab.title)
                .font(.system(size: 13))
                .lineLimit(1)

            if tab.kind == .agent {
                Text(qualityLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if active || hovering {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Cerrar tab")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(active ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
    }

    /// La tab dice con qué calidad se retoma el hilo (UX, Lanzar y retomar).
    private var qualityLabel: String {
        switch tab.resumeQuality {
        case .exact: return "exacta"
        case .latestInDir: return "última"
        case .fresh: return "nueva"
        }
    }
}

/// Los tabs dentro del app bar. El `+` va al final de la lista.
struct TabBarView: View {
    @ObservedObject var model: WorkspaceModel
    @State private var showingMenu = false

    var body: some View {
        // Sin `ScrollView` a propósito: un `ScrollView` horizontal centra su
        // contenido y los tabs se iban al extremo derecho del app bar, que es
        // justo donde no deben. Con muchos tabs el recorte se resuelve después.
        HStack(spacing: 0) {
            ForEach(model.tabs) { tab in
                TabItem(
                    tab: tab,
                    active: tab.id == model.activeTabId,
                    onSelect: { model.onSelectTab(tab.id) },
                    onClose: { model.onCloseTab(tab.id) })
            }

            Button {
                showingMenu = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Nueva tab")
            .popover(isPresented: $showingMenu, arrowEdge: .bottom) {
                TabMenuView(model: model) { showingMenu = false }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: AppBarView.height)
    }
}
