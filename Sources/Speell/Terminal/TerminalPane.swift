import AppKit

/// Contenedor AppKit que muestra la surface de la tab activa y mantiene vivas
/// las demás (procesos incluidos). No decide qué tab está activa: eso lo hace
/// el composition root.
final class TerminalPane: NSView {
    private var surfaceViews: [UUID: SurfaceView] = [:]
    private var activeTabId: UUID?

    /// Crea o reemplaza la surface de una tab. Quien la crea es el controller.
    func install(_ surfaceView: SurfaceView, forTab id: UUID) {
        surfaceViews[id]?.removeFromSuperview()
        surfaceViews[id] = surfaceView
        surfaceView.autoresizingMask = [.width, .height]
        surfaceView.frame = bounds
        addSubview(surfaceView)
        applyVisibility()
    }

    /// Muestra la surface de esa tab y esconde el resto. `nil` las esconde todas.
    func show(tabId: UUID?) {
        activeTabId = tabId
        applyVisibility()
    }

    func surfaceView(forTab id: UUID) -> SurfaceView? {
        surfaceViews[id]
    }

    /// Saca la surface del árbol: su deinit libera la surface de libghostty y
    /// con ella el proceso hijo.
    func removeSurface(forTab id: UUID) {
        guard let view = surfaceViews.removeValue(forKey: id) else { return }
        view.removeFromSuperview()
    }

    func removeAll() {
        for id in surfaceViews.keys {
            removeSurface(forTab: id)
        }
        activeTabId = nil
    }

    private func applyVisibility() {
        for (id, view) in surfaceViews {
            view.isHidden = id != activeTabId
            view.updateOcclusion()
        }
    }
}
