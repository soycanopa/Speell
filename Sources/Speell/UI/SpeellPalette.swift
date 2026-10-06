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
    /// `WorkspaceModel.terminalBackgroundHex` (el override persistido); el
    /// `backgroundHex` de la spec es solo el valor de siembra.
    static var surfaceBackground: Color { color(fromHex: TerminalPalette.backgroundHex) }

    /// `#RRGGBB` a `Color`, por `NSColor(srgbRed:)` como `windowBackground`.
    /// El parseo es a mano, sin `Scanner`: con el `#` delante,
    /// `scanHexInt64` no lee nada y el color sale negro. Nada de opacidad ni
    /// formatos cortos: los hex del producto son siempre de 6.
    static func color(fromHex hex: String) -> Color {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt64(digits, radix: 16) ?? 0
        return Color(nsColor: NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1))
    }

    /// `Color` a `#RRGGBB`, la vuelta del `color(fromHex:)` para persistir lo
    /// que el usuario elige en la configuración.
    static func hex(from color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        return String(
            format: "#%02x%02x%02x",
            Int(round(c.redComponent * 255)),
            Int(round(c.greenComponent * 255)),
            Int(round(c.blueComponent * 255)))
    }

    /// Margen que la ventana deja entre su borde y el contenido: app bar,
    /// sidebar y terminal.
    static let windowPadding: CGFloat = 8

    /// El margen de arriba, menor que el del resto de lados: la tab arranca a
    /// 6 pt del borde de la ventana, más cerca del tope que el resto del
    /// contenido del resto de los lados.
    static let windowTopPadding: CGFloat = 6

    /// Radio de las esquinas de la sidebar y de la terminal.
    static let cornerRadius: CGFloat = 8

    /// La forma completamente redondeada, para las superficies que no tienen
    /// tab pegada (la configuración). Mismo tipo que `pane` para que puedan
    /// elegirse en el mismo `clipShape`.
    static var corner: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: cornerRadius,
            style: .continuous)
    }

    /// La forma de la tab activa: redondeada arriba, recta abajo, porque nace
    /// pegada a la terminal y se continúa en ella.
    static var attachedTab: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: cornerRadius,
            style: .continuous)
    }

    /// La forma del pane de la terminal: redondeada abajo en ambas esquinas y
    /// arriba en la derecha, que da contra el chrome. Arriba a la izquierda va
    /// recta solo cuando la tab activa es la primera —ahí nace la tab, y una
    /// esquina redondeada abriría una cuña de chrome justo donde la tab se une
    /// con la terminal—; si la tab activa es otra, esa esquina queda expuesta
    /// y tiene que ir redondeada.
    static func pane(roundTopLeading: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: roundTopLeading ? cornerRadius : 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: cornerRadius,
            style: .continuous)
    }

    /// La forma de la sidebar: redondeada a la izquierda, que da contra el
    /// margen de la ventana. A la derecha va recta: es el lado que enfrenta a
    /// la terminal, y dos esquinas redondeadas enfrentadas a través del canal
    /// se leían como un círculo entre las dos.
    static var sidebarPane: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0,
            style: .continuous)
    }

    /// Lo que el divisor del split view suma al hueco visual entre la sidebar
    /// y la terminal (NSSplitViewController lo fija en 9 en macOS 26, y ni el
    /// grosor ni el estilo se dejan sobreescribir): es transparente pero
    /// ocupa sitio. Se descuenta del padding interno de la sidebar para que
    /// el canal mida lo mismo que los márgenes de la ventana.
    static let splitDividerAllowance: CGFloat = 9
}
