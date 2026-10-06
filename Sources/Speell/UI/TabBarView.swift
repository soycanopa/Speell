import SwiftUI

/// Una tab: título y botón de cerrar siempre visible.
/// El punto de estado llega con los avisos (fase 4).
struct TabItem: View {
    let tab: Tab
    let active: Bool
    let backgroundHex: String
    var onSelect: () -> Void
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(tab.title)
                .font(.system(size: 13))
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Cerrar tab")
        }
        .padding(.horizontal, 10)
        // Cuatro puntos menos que el app bar: dos de aire arriba. Abajo no hay
        // aire — el fondo de la tab activa baja hasta el borde del app bar.
        .frame(height: AppBarView.height - 4)
        // La tab activa nace de la terminal: mismo tono, esquinas redondeadas
        // solo arriba y el borde inferior en el borde mismo del app bar, donde
        // empieza la terminal. Cubre la franja entera —de arriba a abajo— así
        // que su tope queda a `windowTopPadding` del borde de la ventana.
        // Las inactivas son solo texto sobre la franja.
        .background(alignment: .top) {
            if active {
                SpeellPalette.color(fromHex: backgroundHex)
                    .frame(height: AppBarView.height)
                    .clipShape(SpeellPalette.attachedTab)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
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
                    backgroundHex: model.terminalBackgroundHex,
                    onSelect: { model.onSelectTab(tab.id) },
                    onClose: { model.onCloseTab(tab.id) })
            }

            Button {
                showingMenu = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 24, height: AppBarView.height - 4)
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
