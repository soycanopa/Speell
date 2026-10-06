import Foundation

/// Tabs shell: abrir, seleccionar y cerrar. Las de agente están en la
/// extensión de tabs de agente.
extension WorkspaceController {
    /// Botón del vacío y ⌘T: una terminal, sin preguntar.
    func newShellTab() {
        guard let project = model.activeProject else { return }
        addShellTab(projectId: project.id)
    }

    func closeActiveTab() {
        guard let id = model.activeTabId else { return }
        closeTab(id: id)
    }

    func selectTabNumber(_ number: Int) {
        let tabs = model.tabs
        guard number >= 1, number <= tabs.count else { return }
        selectTab(id: tabs[number - 1].id)
    }

    func addShellTab(projectId: UUID) {
        guard let project = projects.project(id: projectId) else { return }
        let cwd = FileManager.default.fileExists(atPath: project.path)
            ? project.path
            : NSHomeDirectory()

        let tab = Tab(
            projectId: projectId,
            kind: .shell,
            cwd: cwd,
            title: shellTitle(for: cwd))
        sessions.add(tab)
        installSurface(for: tab)
        show(tabId: tab.id)
        projects.touch(id: projectId)
        refresh()
        focusActiveSurface()
    }

    func selectTab(id: UUID) {
        guard sessions.tabs.contains(where: { $0.id == id }) else { return }
        show(tabId: id)
        focusActiveSurface()
    }

    func closeTab(id: UUID) {
        guard let tab = sessions.tabs.first(where: { $0.id == id }) else { return }
        let siblings = sessions.tabs(of: tab.projectId)
        let index = siblings.firstIndex { $0.id == id } ?? 0

        // Quitar la surface del pane la libera y mata el proceso de esa tab.
        pane.removeSurface(forTab: id)
        sessions.remove(id: id)

        if model.activeTabId == id {
            let remaining = sessions.tabs(of: tab.projectId)
            if remaining.isEmpty {
                show(tabId: nil)
            } else {
                show(tabId: remaining[min(index, remaining.count - 1)].id)
            }
        }

        refresh()
        focusActiveSurface()
    }

    func shellTitle(for cwd: String) -> String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty || cwd == NSHomeDirectory() ? "Terminal" : name
    }
}
