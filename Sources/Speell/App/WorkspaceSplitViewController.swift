import AppKit

/// Split view del workspace: la sidebar y la terminal.
///
/// Publica el ancho de la sidebar porque el app bar tiene que moverse con el
/// divider para que los tabs sigan arrancando en el borde de la terminal.
/// No se puede poner un delegate externo: `NSSplitViewController` ya es el
/// delegate de su propio `splitView` y macOS lo rechaza
/// ("A SplitView managed by a SplitViewController cannot have its delegate
/// modified"), así que hay que engancharse desde dentro.
final class WorkspaceSplitViewController: NSSplitViewController {
    /// El item de la sidebar. Se asigna a mano porque el ancho se lee de aquí.
    ///
    /// No se puede deducir por índice: `splitView.subviews.first` no está
    /// garantizado que sea la sidebar y, en la práctica, devuelve la terminal.
    /// Con 240 de sidebar y 743 de terminal eso empujaba los tabs 831 px a la
    /// derecha en lugar de 318.
    weak var sidebarItem: NSSplitViewItem?

    /// Se llama con el borde de la terminal cada vez que cambia el divider.
    var onSidebarWidthChanged: ((CGFloat) -> Void)?

    /// Distancia desde el borde izquierdo del contenido hasta donde empieza la
    /// terminal: el borde derecho de la sidebar más el divisor que macOS
    /// dibuja entre las dos.
    var contentLeadingOffset: CGFloat? {
        guard let item = sidebarItem else { return nil }
        return item.viewController.view.frame.maxX + splitView.dividerThickness
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        guard let width = contentLeadingOffset else { return }
        onSidebarWidthChanged?(width)
    }
}
