import Foundation

/// Proyectos fijados: alta, baja, orden por última actividad y cuál está activo.
/// No lanza procesos ni conoce las tabs.
final class ProjectStore {
    private struct Document: Codable {
        var projects: [Project]
        var lastActiveProjectId: UUID?
    }

    private static let fileName = "projects.json"

    private let store: JSONStore
    private(set) var projects: [Project] = []
    private(set) var lastActiveProjectId: UUID?

    init(store: JSONStore = .applicationSupport) {
        self.store = store
        guard let document = store.load(Document.self, named: Self.fileName) else { return }
        projects = document.projects
        lastActiveProjectId = document.lastActiveProjectId
    }

    /// Orden de la sidebar: última actividad arriba.
    var ordered: [Project] {
        projects.sorted { $0.lastActiveAt > $1.lastActiveAt }
    }

    func project(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    /// Fija una carpeta. Si ya estaba fijada, devuelve la fila existente.
    @discardableResult
    func add(path: String) -> Project {
        let standardized = (path as NSString).standardizingPath
        if let existing = projects.first(where: { $0.path == standardized }) {
            return existing
        }
        let project = Project(path: standardized)
        projects.append(project)
        save()
        return project
    }

    /// Quita de la sidebar. Nunca toca el disco.
    func remove(id: UUID) {
        projects.removeAll { $0.id == id }
        if lastActiveProjectId == id {
            lastActiveProjectId = nil
        }
        save()
    }

    func touch(id: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].lastActiveAt = Date()
        save()
    }

    func setActive(id: UUID?) {
        guard lastActiveProjectId != id else { return }
        lastActiveProjectId = id
        save()
    }

    private func save() {
        store.save(
            Document(projects: projects, lastActiveProjectId: lastActiveProjectId),
            named: Self.fileName)
    }
}
