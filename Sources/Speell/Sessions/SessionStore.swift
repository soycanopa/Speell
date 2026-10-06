import Foundation

/// Punteros de sesión: una tab por fila, con su cwd.
/// No guarda transcript; el hilo vive en el CLI del agente.
final class SessionStore {
    private static let fileName = "tabs.json"

    private let store: JSONStore
    private(set) var tabs: [Tab] = []

    init(store: JSONStore = .applicationSupport) {
        self.store = store
        tabs = store.load([Tab].self, named: Self.fileName) ?? []
    }

    func tabs(of projectId: UUID) -> [Tab] {
        tabs.filter { $0.projectId == projectId }
    }

    func add(_ tab: Tab) {
        tabs.append(tab)
        save()
    }

    func remove(id: UUID) {
        tabs.removeAll { $0.id == id }
        save()
    }

    /// Al quitar un proyecto, sus punteros salen de Speell. Los hilos siguen
    /// en el store de cada agente.
    func removeTabs(of projectId: UUID) {
        tabs.removeAll { $0.projectId == projectId }
        save()
    }

    private func save() {
        store.save(tabs, named: Self.fileName)
    }
}
