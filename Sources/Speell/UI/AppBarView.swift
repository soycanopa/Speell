import SwiftUI

/// La franja de arriba de la ventana, de ancho completo.
///
/// Cruza por encima de la sidebar y de la terminal. A la izquierda deja el hueco
/// donde macOS dibuja los botones de ventana; a la derecha van los tabs y,
/// después, la zona reservada para los iconos del panel que se va a desarrollar.
struct AppBarView: View {
    /// Hueco que se deja a la izquierda para los botones de ventana, que macOS
    /// sigue dibujando aunque la barra de título esté oculta.
    static let windowControlsWidth: CGFloat = 78

    /// Alto de la franja.
    static let height: CGFloat = 38

    @ObservedObject var model: WorkspaceModel

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: Self.windowControlsWidth)

            TabBarView(model: model)

            Spacer(minLength: 0)
        }
        .frame(height: Self.height)
    }
}
