import AppKit

/// Las familias de tipografía monoespaciadas instaladas, para el selector de
/// la terminal. La condición es empírica, no una lista curada a mano: una
/// familia es mono si sus glifos comparten avance — cuatro "i" y cuatro "W"
/// miden lo mismo. Así entran todas las monos que el usuario tenga y queden
/// fuera las proporcionales, que es lo que se ve bien en una terminal.
enum MonoFonts {
    /// Familias de símbolos: avance uniforme pero sin texto que dibujar.
    private static let symbolFamilies: Set<String> = [
        "LastResort", "Webdings", "Wingdings", "Wingdings 2", "Wingdings 3",
        "Apple Color Emoji",
    ]

    /// Familias instaladas y monoespaciadas, alfabéticas. Se enumera por
    /// familias (`availableFontFamilies`), no por fuentes: es lo que el
    /// usuario conoce y lo que `font-family` de ghostty espera.
    static func installed() -> [String] {
        NSFontManager.shared.availableFontFamilies
            .filter { !symbolFamilies.contains($0) }
            .filter(isMonospace)
            .sorted()
    }

    static func isMonospace(_ family: String) -> Bool {
        // Reserva del sistema: dibuja cajas de sustitución, no texto.
        guard family != "LastResort",
              let font = NSFont(name: family, size: 12)
        else { return false }

        let narrow = width("iiii", font: font)
        let wide = width("WWWW", font: font)
        guard let narrow, let wide else { return false }
        return abs(narrow - wide) < 0.5
    }

    private static func width(_ text: String, font: NSFont) -> CGFloat? {
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        return width.isFinite && width > 0 ? width : nil
    }
}
