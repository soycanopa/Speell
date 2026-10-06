import Foundation

/// Carpeta fijada en la sidebar. Un proyecto no es un workspace multi-root.
struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var path: String
    var displayName: String
    var lastActiveAt: Date

    init(id: UUID = UUID(), path: String, lastActiveAt: Date = Date()) {
        self.id = id
        self.path = path
        self.displayName = (path as NSString).lastPathComponent
        self.lastActiveAt = lastActiveAt
    }
}
