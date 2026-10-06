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
        let cover = DividerHandleView()
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

/// La franja del divisor: pinta el fondo de la ventana encima del punto
/// agarradero que el sistema dibuja en el centro, y al hacer hover muestra un
/// handle en forma de pill vertical. No intercepta el mouse (`hitTest` nulo):
/// el arrastre del divider pasa directo al divisor de abajo.
private final class DividerHandleView: NSView {
    private let pill = CALayer()
    private var hovering = false {
        didSet { fadePill() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = SpeellPalette.windowBackground.cgColor
        pill.cornerRadius = 2
        pill.backgroundColor = NSColor.white.withAlphaComponent(0.28).cgColor
        pill.opacity = 0
        layer?.addSublayer(pill)
    }

    required init?(coder: NSCoder) {
        fatalError("DividerHandleView no se crea desde un coder")
    }

    override func layout() {
        super.layout()
        // Pill vertical centrada en la franja; con el arrastre la vista se
        // mueve y la pill viaja con ella.
        pill.frame = CGRect(
            x: (bounds.width - 4) / 2,
            y: (bounds.height - 36) / 2,
            width: 4,
            height: 36)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    private func fadePill() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        pill.opacity = hovering ? 1 : 0
        CATransaction.commit()
    }

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
