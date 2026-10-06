import Foundation

/// La clave `notifications` del `settings.json` de Agy, documentada por
/// Antigravity: "triggers a system desktop notification and a terminal bell
/// chime when a long-running task completes or requires your attention".
/// Default `false`. Speell no la escribe nunca por su cuenta: `enable` es
/// una acción explícita del usuario desde la configuración, y el merge
/// conserva el resto del archivo, que es config de otro producto.
enum AgyNoticeSettings {
    /// Ruta documentada por Antigravity (docs de settings, tab CLI).
    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/antigravity-cli/settings.json")
    }

    static func isEnabled(fileURL: URL = defaultURL) -> Bool {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else { return false }
        return dictionary["notifications"] as? Bool == true
    }

    /// Pone `notifications: true` conservando el resto de las claves. Si el
    /// archivo no existe, nace con solo esta clave.
    static func enable(fileURL: URL = defaultURL) throws {
        var dictionary: [String: Any] = [:]
        if let data = try? Data(contentsOf: fileURL),
           let object = try? JSONSerialization.jsonObject(with: data),
           let existing = object as? [String: Any] {
            dictionary = existing
        }
        dictionary["notifications"] = true
        let data = try JSONSerialization.data(
            withJSONObject: dictionary,
            options: [.prettyPrinted, .sortedKeys])
        try data.write(to: fileURL, options: .atomic)
    }
}
