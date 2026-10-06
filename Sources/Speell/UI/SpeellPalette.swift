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

    /// `#RRGGBB` a `Color`, por `NSColor(srgbRed:)` como `windowBackground`.
    /// El parseo es a mano, sin `Scanner`: con el `#` delante,
    /// `scanHexInt64` no lee nada y el color sale negro. Nada de opacidad ni
    /// formatos cortos: los hex del producto son siempre de 6.
    private static func color(fromHex hex: String) -> Color {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt64(digits, radix: 16) ?? 0
        return Color(nsColor: NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1))
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

    /// La forma de la tab activa: redondeada arriba, recta abajo, porque nace
    /// pegada a la terminal y se continúa en ella.
    static var attachedTab: HalfRoundedRect {
        HalfRoundedRect(cornerRadius: cornerRadius, roundedTop: true)
    }

    /// La forma del pane de la terminal: recto arriba —el app bar y la tab
    /// activa se apoyan en ese borde—, redondeado abajo.
    static var pane: HalfRoundedRect {
        HalfRoundedRect(cornerRadius: cornerRadius, roundedTop: false)
    }
}

/// Esquinas redondeadas solo en la mitad de arriba o solo en la de abajo.
///
/// La tab activa redondea arriba y la terminal abajo: se empalman la una con
/// la otra y las esquinas del empalme van rectas. `UnevenRoundedRectangle`
/// pide macOS 13.4 y el target es 13.0, así que el path es propio.
struct HalfRoundedRect: Shape {
    var cornerRadius: CGFloat
    var roundedTop: Bool

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.width / 2, rect.height / 2)
        var path = Path()
        if roundedTop {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addArc(
                tangent1End: CGPoint(x: rect.minX, y: rect.minY + r),
                tangent2End: CGPoint(x: rect.minX + r, y: rect.minY),
                radius: r)
            path.addArc(
                tangent1End: CGPoint(x: rect.maxX - r, y: rect.minY),
                tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r),
                radius: r)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addArc(
                tangent1End: CGPoint(x: rect.maxX, y: rect.maxY - r),
                tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY),
                radius: r)
            path.addArc(
                tangent1End: CGPoint(x: rect.minX + r, y: rect.maxY),
                tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r),
                radius: r)
        }
        path.closeSubpath()
        return path
    }
}
