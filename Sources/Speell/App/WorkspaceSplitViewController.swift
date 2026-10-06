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
    /// El header de `NSSplitViewController` lo documenta: para dar un split
    /// view propio se asigna `splitView` antes de que la vista cargue.
    override func loadView() {
        splitView = WorkspaceSplitView()
        super.loadView()
    }

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
        // La tapa sigue a la franja del divisor, que se mueve al arrastrar.
        // El rect se lee de la vista del divisor: el método dedicado del split
        // view cambió de firma entre SDKs y la vista es estable.
        dividerCover.frame = dividerStripRect
        // El sistema recoloca su divisor por encima de la tapa al maquetar;
        // se vuelve a poner al frente, que es donde pinta.
        splitView.addSubview(dividerCover, positioned: .above, relativeTo: nil)
        guard let width = contentLeadingOffset else { return }
        onSidebarWidthChanged?(width)
    }

    /// Tapa sobre el divisor del sistema: en macOS 26 pinta un punto agarradero
    /// en el centro de la franja aunque `dividerColor` vaya en claro. La tapa
    /// pinta el fondo de la ventana encima y no intercepta el mouse
    /// (`hitTest` nulo), así el arrastre del divider pasa directo al divisor.
    private lazy var dividerCover: NSView = {
        let cover = PassthroughView()
        cover.wantsLayer = true
        cover.layer?.backgroundColor = SpeellPalette.windowBackground.cgColor
        splitView.addSubview(cover)
        return cover
    }()

    /// La franja del divisor entre la sidebar y la terminal.
    private var dividerStripRect: NSRect {
        splitView.subviews
            .first { String(describing: type(of: $0)).contains("Divider") }?
            .frame ?? .zero
    }
}

/// Pinta su color pero deja pasar los eventos a las vistas de abajo.
private final class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// El split view del workspace: el del sistema, pero sin pintar la línea del
/// divisor. La separación entre la sidebar y la terminal es el hueco del fondo
/// de la ventana (`docs/UI.md`); el rect del divisor sigue ahí y es el agarre
/// para arrastrar.
final class WorkspaceSplitView: NSSplitView {
    init() {
        super.init(frame: .zero)
        isVertical = true
    }

    required init?(coder: NSCoder) {
        fatalError("WorkspaceSplitView no se crea desde un coder")
    }

    override var dividerColor: NSColor { .clear }
}
