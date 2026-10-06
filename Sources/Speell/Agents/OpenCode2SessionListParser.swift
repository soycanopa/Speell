import Foundation

/// Parsea el JSON de `opencode2 session list --format json` (opencode v2.0.22).
/// Salida real capturada 2026-10-06:
///
///     [
///       {
///         "id": "ses_ef927c45cffeFaeiW5COUJ0FqS",
///         "updated": 1791116196773,
///         "created": 1791116196773,
///         "projectId": "e22c0befcd3aab577c593974d56decf884468691",
///         "directory": "/"
///       }
///     ]
///
/// `title` no apareció en la captura porque esas sesiones no lo tienen; el
/// modelo `Session.Info` del propio binario (spec OpenAPI vía
/// `opencode2 api GET /openapi.json`) lo declara opcional, así que aquí también.
/// Si el CLI cambia el formato, el parser devuelve lista vacía y el modal
/// degrada a "sesión nueva" (FLOW F2); no rompe nada.
enum OpenCode2SessionListParser {
    private struct Element: Decodable {
        let id: String
        let title: String?
        /// Época en milisegundos, igual que `time_updated` del store del CLI.
        let updated: Double?
    }

    static func sessions(from output: String) -> [SessionRef] {
        guard let data = output.data(using: .utf8),
              let elements = try? JSONDecoder().decode([Element].self, from: data)
        else { return [] }

        return elements.map { element in
            SessionRef(
                id: element.id,
                title: element.title.flatMap { $0.isEmpty ? nil : $0 } ?? "sin título",
                updatedAt: element.updated.map { Date(timeIntervalSince1970: $0 / 1000) })
        }
    }
}
