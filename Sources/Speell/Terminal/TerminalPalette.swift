import Foundation
import GhosttyKit

/// El fondo que Speell impone a la terminal.
///
/// libghostty no expone ningún setter de color en su C API: la única vía para
/// cambiar un valor de config es cargar un archivo (`ghostty.h:1149`). Speell
/// escribe el suyo en su carpeta de Application Support y lo carga **después**
/// de la config del usuario y **antes** de `ghostty_config_finalize`, que es
/// donde queda resuelto el valor final. Así el fondo de Speell gana sin tocar
/// el archivo de configuración del usuario.
///
/// La carpeta es inyectable para que los tests no escriban en el disco real.
enum TerminalPalette {
    /// Fondo de la terminal. Es decisión de producto y vive en `docs/UI.md`.
    static let backgroundHex = "#161616"

    static let overrideFileName = "ghostty.conf"

    /// Contenido del override. Solo lo que Speell impone; lo demás sigue
    /// saliendo de la config del usuario.
    static var overrideContents: String {
        "background = \(backgroundHex)\n"
    }

    /// Escribe el override y devuelve dónde quedó, o `nil` si falló.
    @discardableResult
    static func writeOverride(in directory: URL) -> URL? {
        let url = directory.appendingPathComponent(overrideFileName)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try overrideContents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            FileHandle.standardError.write(
                Data("no se pudo escribir el override de libghostty: \(error)\n".utf8))
            return nil
        }
    }

    /// Escribe y carga el override sobre una config ya abierta.
    static func apply(to config: ghostty_config_t, in directory: URL) {
        guard let url = writeOverride(in: directory) else { return }
        ghostty_config_load_file(config, url.path)
    }

    /// Carpeta donde Speell guarda su estado; la misma que los stores JSON.
    static var applicationSupportDirectory: URL {
        JSONStore.applicationSupport.directory
    }
}