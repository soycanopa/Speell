import Foundation

/// Documentos JSON con escritura atómica. La carpeta es inyectable para que los
/// tests no toquen la Application Support del usuario.
struct JSONStore {
    let directory: URL

    /// Carpeta de Speell en Application Support del usuario.
    static let applicationSupport: JSONStore = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return JSONStore(directory: base.appendingPathComponent("Speell", isDirectory: true))
    }()

    func load<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, named name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("no se pudo guardar \(name): \(error)\n".utf8))
        }
    }
}
