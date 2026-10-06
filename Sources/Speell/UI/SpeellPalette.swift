import AppKit
import SwiftUI

/// Tokens de color y forma del chrome de Speell.
///
/// Lo que sí viene del sistema se usa directo (`Color(nsColor:)`); lo que no,
/// vive aquí para poder ajustarlo sin recorrer el código. Los valores son
/// decisión de producto y están anotados en `docs/UI.md`.
enum SpeellPalette {
    /// Fondo de toda la ventana: app bar, sidebar, margen exterior y
    /// separación entre la sidebar y la terminal.
    ///
    /// Es el tono al que resuelve `underPageBackgroundColor` en oscuro, con el
    /// que macOS enmarca contenido `#1E1E1E` (`controlBackgroundColor`, el
    /// mismo tono de la terminal): chrome claro alrededor, surface oscura
    /// dentro.
    ///
    /// Vive como `NSColor` y no como `Color` porque el color lo pinta la
    /// ventana, que es AppKit, y las vistas de arriba solo lo heredan. Un solo
    /// valor, una sola fuente.
    static let windowBackground = NSColor(
        srgbRed: 40 / 255, green: 40 / 255, blue: 40 / 255, alpha: 1)

    /// El mismo fondo como `Color`, para las vistas que lo necesiten.
    static var windowBackgroundColor: Color { Color(nsColor: windowBackground) }

    /// El tono de la terminal, como `Color`, para el chrome que empalma con
    /// ella: la tab activa y el vacío del pane. La fuente única del hex es
    /// `TerminalPalette.backgroundHex`.
    static var surfaceBackground: Color { color(fromHex: TerminalPalette.backgroundHex) }

    /// `#RRGGBB` a `Color`. Nada de opacidad ni formatos cortos: los hex del
    /// producto son siempre de 6.
    private static func color(fromHex hex: String) -> Color {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

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
