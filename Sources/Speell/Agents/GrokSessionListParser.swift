import Foundation

/// Parsea la tabla de `grok sessions list`. El CLI no tiene salida JSON, así que
/// se leen las filas por el UUID inicial y se deja el resto como título.
/// El título viene truncado al ancho de la terminal: se conserva tal cual.
///
/// Formato observado (grok 1.0.46):
///
///     (no label)
///     SESSION ID                            CREATED     UPDATED     STATUS      SUMMARY
///     019f5191-4164-7f10-ad66-16c5acca2f0a  2026-07-11  2026-07-11  remote  Project Status Review: Current
enum GrokSessionListParser {
    private static let rowPattern =
        #"^\s*([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*)$"#

    static func sessions(from output: String) -> [SessionRef] {
        guard let regex = try? NSRegularExpression(pattern: rowPattern) else { return [] }
        var result: [SessionRef] = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range) else { continue }

            func group(_ index: Int) -> String {
                guard let groupRange = Range(match.range(at: index), in: text) else { return "" }
                return String(text[groupRange])
            }

            let summary = group(5).trimmingCharacters(in: .whitespaces)
            result.append(SessionRef(
                id: group(1),
                title: summary.isEmpty ? "sin título" : summary,
                updatedAt: date(from: group(3))))
        }
        return result
    }

    /// El CLI imprime las fechas como `YYYY-MM-DD` en la zona del usuario.
    private static func date(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }
}
