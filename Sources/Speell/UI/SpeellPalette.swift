import AppKit
import SwiftUI

/// Tokens de color y forma del chrome de Speell.
///
/// Lo que sí viene del sistema se usa directo (`Color(nsColor:)`); lo que no,
/// vive aquí para poder ajustarlo sin recorrer el código. Los valores son
/// decisión de producto y están anotados en `docs/UI.md`.
enum SpeellPalette {
    /// Fondo de toda la ventana: app bar, margen exterior y separación entre la
    /// sidebar y la terminal.
    ///
    /// Vive como `NSColor` y no como `Color` porque el color lo pinta la
    /// ventana, que es AppKit, y las vistas de arriba solo lo heredan. Un solo
    /// valor, una sola fuente.
    static let windowBackground = NSColor(
        srgbRed: 24 / 255, green: 24 / 255, blue: 24 / 255, alpha: 1)

    /// El mismo fondo como `Color`, para las vistas que lo necesiten.
    static var windowBackgroundColor: Color { Color(nsColor: windowBackground) }

    /// Capa oscura de la sidebar, de 0 a 1. Va detrás del contenido, no
    /// encima, para que el texto y las filas no se atenúen.
    static let sidebarDim = Color.black.opacity(0.08)

    /// Margen que la ventana deja entre su borde y el contenido: app bar,
    /// sidebar y terminal.
    static let windowPadding: CGFloat = 8

    /// Radio de las esquinas de la sidebar y de la terminal.
    static let cornerRadius: CGFloat = 8

    /// La forma redondeada que comparten la sidebar y la terminal.
    static var corner: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}
