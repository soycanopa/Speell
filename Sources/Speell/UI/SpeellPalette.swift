import SwiftUI

/// Tokens de color del chrome de Speell.
///
/// Lo que sí viene del sistema se usa directo (`Color(nsColor:)`); lo que no,
/// vive aquí para poder ajustarlo sin recorrer el código. Los valores son
/// decisión de producto y están anotados en `docs/UI.md`.
enum SpeellPalette {
    /// Capa oscura de la sidebar, de 0 a 1. Va detrás del contenido, no
    /// encima, para que el texto y las filas no se atenúen.
    static let sidebarDim = Color.black.opacity(0.08)
}
