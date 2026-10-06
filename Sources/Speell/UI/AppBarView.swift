import SwiftUI

/// La franja de arriba de la ventana, de ancho completo.
///
/// Cruza por encima de la sidebar y de la terminal. A la izquierda deja el hueco
/// que ocupa la sidebar, para que los tabs arranquen exactamente en el borde de
/// la terminal. macOS dibuja los botones de ventana en esa misma franja, encima
/// de la sidebar; no hace falta reservarles ancho aparte porque caen dentro del
/// hueco. A su derecha quedan los tabs y, después, la zona reservada para los
/// iconos del panel que se va a desarrollar.
struct AppBarView: View {
    /// Alto de la franja.
    ///
    /// 36: con 28 la tab quedaba en 24 y se leía apretada para texto de 13.
    /// La tab activa mide esto menos 4, y la ventana compensa el alto con este
    /// valor en `AppDelegate`.
    static let height: CGFloat = 36

    @ObservedObject var model: WorkspaceModel

    var body: some View {
        HStack(spacing: 0) {
            // Hueco a la izquierda: toda la sidebar más el divider, para que los
            // tabs arranquen exactamente en el borde de la terminal.
            //
            // Los botones de ventana NO se suman: solo ocupan la parte de la
            // franja que cae sobre la sidebar, y para entonces ya los dejamos
            // atrás. Sumarlos empujaba los tabs 77 px más adentro de la
            // terminal de lo que toca.
            Color.clear
                .frame(width: model.contentLeadingOffset)

            // `maxWidth: .infinity` es lo que hace que los tabs ocupen todo lo
            // que queda del app bar; sin esto el `HStack` se ajusta a su tamaño
            // ideal y los tabs acaban pegados al borde derecho.
            TabBarView(model: model)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // El `HStack` necesita el ancho completo explícitamente: dentro de un
        // `NSHostingView` que lo aloja, si no, se ajusta a su tamaño ideal y lo
        // centra, y los tabs terminan pegados al borde derecho.
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
    }
}
