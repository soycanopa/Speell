import Foundation
import GhosttyKit

/// El override que Speell impone a la terminal: fondo, tipografía y tamaño.
///
/// libghostty no expone setters en su C API: la única vía para cambiar valores
/// de config es cargar un archivo (`ghostty.h:1149`). Speell escribe el suyo
/// en su carpeta de Application Support y lo carga **después** de la config
/// del usuario y **antes** del `ghostty_config_finalize`.
///
/// Desde que existe la configuración de la app, ese archivo es estado del
/// usuario: si existe se carga tal cual (el dueño es el usuario, no un
/// rewrite de arranque); si no existe se siembra con los valores de la spec.
/// `writeOverride(values:in:)` es la única escritura y siempre reescribe el
/// archivo completo.
/// La carpeta es inyectable para que los tests no escriban en el disco real.
enum TerminalPalette {
    /// Fondo por defecto. Es decisión de producto y vive en `docs/UI.md`.
    static let backgroundHex = "#161616"

    /// Tamaño de fuente por defecto en macOS, del propio pin
    /// (`src/config/Config.zig`: `"font-size": f32 = … .macos => 13`).
    static let defaultFontSize = 13.0

    static let overrideFileName = "ghostty.conf"

    /// Fondo vigente: el del override si existe, o el de la spec.
    static func backgroundHex(in directory: URL) -> String {
        values(in: directory)["background"] ?? backgroundHex
    }

    /// Tipografía vigente, o `nil` si no se fijó (la bundled de ghostty).
    static func fontFamily(in directory: URL) -> String? {
        values(in: directory)["font-family"]
    }

    /// Tamaño vigente, o el default del pin si no se fijó.
    static func fontSize(in directory: URL) -> Double {
        values(in: directory)["font-size"].flatMap(Double.init) ?? defaultFontSize
    }

    /// Cambia el fondo y lo persiste conservando las demás claves.
    @discardableResult
    static func writeOverride(hex: String, in directory: URL) -> URL? {
        var values = values(in: directory)
        values["background"] = hex
        return writeOverride(values: values, in: directory)
    }

    /// Escribe el override completo. La única escritura; reemplaza el archivo.
    @discardableResult
    static func writeOverride(values: [String: String], in directory: URL) -> URL? {
        let url = directory.appendingPathComponent(overrideFileName)
        let contents = values
            .sorted { $0.key < $1.key }
            .map { "\($0.key) = \($0.value)\n" }
            .joined()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            FileHandle.standardError.write(
                Data("no se pudo escribir el override de libghostty: \(error)\n".utf8))
            return nil
        }
    }

    /// Carga el override sobre una config ya abierta. Si el archivo no existe
    /// se siembra con el fondo de la spec; si existe es estado del usuario y
    /// se carga sin reescribirlo.
    static func apply(to config: ghostty_config_t, in directory: URL) {
        let url = directory.appendingPathComponent(overrideFileName)
        if FileManager.default.fileExists(atPath: url.path) {
            ghostty_config_load_file(config, url.path)
            return
        }
        guard let written = writeOverride(hex: backgroundHex, in: directory) else { return }
        ghostty_config_load_file(config, written.path)
    }

    /// Carpeta donde Speell guarda su estado; la misma que los stores JSON.
    static var applicationSupportDirectory: URL {
        JSONStore.applicationSupport.directory
    }

    /// El override como diccionario. Formato propio de una sola clave por
    /// línea (`clave = valor`); una línea que no parsee se ignora.
    static func values(in directory: URL) -> [String: String] {
        let url = directory.appendingPathComponent(overrideFileName)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for line in contents.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty {
                result[key] = value
            }
        }
        return result
    }
}
