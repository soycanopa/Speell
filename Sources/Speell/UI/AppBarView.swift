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
    /// 30: la tab es compacta y el borde de la terminal sube con ella —
    /// queda a `windowTopPadding + height` del tope de la ventana.
    static let height: CGFloat = 30

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
            //
            // En configuración no hay tabs: la franja queda limpia y el título
            // de la sección lo lleva el propio contenido.
            if model.appMode == .workspace {
                TabBarView(model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
        // El `HStack` necesita el ancho completo explícitamente: dentro de un
        // `NSHostingView` que lo aloja, si no, se ajusta a su tamaño ideal y lo
        // centra, y los tabs terminan pegados al borde derecho.
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
        // El título de 28 pt que macOS sigue reservando arriba entra al hosting
        // view como safe area: con la franja en [8, 44], 20 pt caen dentro de la
        // zona del sistema y SwiftUI los respeta, empujando los tabs contra el
        // fondo de la franja y por debajo, sobre la terminal. Speell mide su
        // propio chrome, así que la franja entera es área de contenido.
        .ignoresSafeArea()
    }
}
