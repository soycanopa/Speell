import Foundation

/// Carpeta fijada en la sidebar. Un proyecto no es un workspace multi-root.
struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var path: String
    var displayName: String
    var lastActiveAt: Date
    /// Archivado: sale de la sidebar y vive en settings → Archivados hasta
    /// que el usuario lo recupere. La carpeta y los punteros de sesión no se
    /// tocan. Default `false` para el JSON previo, que no trae la clave.
    var archived: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id, path, displayName, lastActiveAt, archived
    }

    init(id: UUID = UUID(), path: String, lastActiveAt: Date = Date()) {
        self.id = id
        self.path = path
        self.displayName = (path as NSString).lastPathComponent
        self.lastActiveAt = lastActiveAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        displayName = try container.decode(String.self, forKey: .displayName)
        lastActiveAt = try container.decode(Date.self, forKey: .lastActiveAt)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
    }
}
