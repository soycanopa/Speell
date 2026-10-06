import AppKit

/// Ciclo de vida de los proyectos: abrir carpeta, seleccionar, archivar,
/// recuperar, renombrar y quitar.
extension WorkspaceController {
    func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Abrir"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let project = projects.add(path: url.path)
        selectProject(id: project.id)

        // FLOW F1: fijar una carpeta abre su primera tab shell.
        if sessions.tabs(of: project.id).isEmpty {
            addShellTab(projectId: project.id)
        }
    }

    func selectProject(id: UUID) {
        guard let project = projects.project(id: id), !project.archived else { return }
        projects.touch(id: id)
        projects.setActive(id: id)

        ensureSurfaces(projectId: id)

        let tabs = sessions.tabs(of: id)
        let wanted = lastTabByProject[id].flatMap { previous in
            tabs.first { $0.id == previous }
        }
        show(tabId: (wanted ?? tabs.last)?.id)
        refresh()
        focusActiveSurface()
    }

    /// Archivar: cierra surfaces y procesos como quitar, pero conserva las
    /// filas de tab y el proyecto. Recuperable desde settings → Archivados.
    /// Es reversible, así que no lleva confirmación.
    func archiveProject(id: UUID) {
        guard projects.project(id: id) != nil else { return }

        for tab in sessions.tabs(of: id) {
            pane.removeSurface(forTab: tab.id)
        }
        lastTabByProject[id] = nil
        projects.archive(id: id)

        if model.activeProjectId == id {
            model.activeTabId = nil
            pane.show(tabId: nil)
            if let next = projects.unarchived.first {
                selectProject(id: next.id)
            } else {
                refresh()
            }
        } else {
            refresh()
        }
    }

    /// Recupera un archivado: vuelve a la sidebar, sin saltar a él.
    func restoreProject(id: UUID) {
        guard let project = projects.project(id: id), project.archived else { return }
        projects.restore(id: id)
        refresh()
    }

    /// Renombra el proyecto con un diálogo modal. El nombre vive solo en
    /// Speell; la carpeta queda igual.
    func renameProject(id: UUID) {
        guard let project = projects.project(id: id) else { return }

        let alert = NSAlert()
        alert.messageText = "Cambiar nombre"
        alert.informativeText = "El nombre vive solo en Speell; la carpeta queda igual."
        alert.alertStyle = .informational
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = project.displayName
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.addButton(withTitle: "Guardar")
        alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        projects.rename(id: id, name: field.stringValue)
        refresh()
    }

    func removeProject(id: UUID) {
        guard let project = projects.project(id: id) else { return }

        let alert = NSAlert()
        alert.messageText = "¿Eliminar \(project.displayName) de Speell?"
        alert.informativeText = "La carpeta no se borra del disco. Sus tabs se cierran y sus procesos mueren."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Eliminar")
        alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        for tab in sessions.tabs(of: id) {
            pane.removeSurface(forTab: tab.id)
        }
        sessions.removeTabs(of: id)
        projects.remove(id: id)
        lastTabByProject[id] = nil

        if model.activeProjectId == id {
            model.activeTabId = nil
            pane.show(tabId: nil)
            if let next = projects.unarchived.first {
                selectProject(id: next.id)
            } else {
                refresh()
            }
        } else {
            refresh()
        }
    }
}
