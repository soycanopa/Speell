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
        // La tapa vive en el contenedor, por encima del split view entero:
        // dentro del split view el sistema recoloca su divisor por encima de
        // cualquier subview y la tapa quedaba siempre debajo.
        if dividerCover.superview !== splitView.superview {
            splitView.superview?.addSubview(dividerCover, positioned: .above, relativeTo: splitView)
        }
        dividerCover.frame = splitView.convert(dividerStripRect, to: dividerCover.superview)
        dividerCover.updateTrackingAreas()
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

    /// La franja del divisor entre la sidebar y la terminal. La tapa también
    /// lleva "Divider" en su nombre: hay que excluirla o se posiciona a sí
    /// misma (nace con frame 0 y se quedaría en 0 para siempre).
    private var dividerStripRect: NSRect {
        splitView.subviews
            .first { sub in
                let name = String(describing: type(of: sub))
                return name.contains("Divider") && !(sub is DividerHandleView)
            }?
            .frame ?? .zero
    }
}

/// La franja del divisor: pinta el fondo de la ventana encima del punto
/// agarradero que el sistema dibuja en el centro, y al hacer hover muestra un
/// handle en forma de pill vertical —del ancho del punto del sistema, un poco
/// más alta. No intercepta el mouse (`hitTest` nulo): el arrastre del divider
/// pasa directo al divisor de abajo.
private final class DividerHandleView: NSView {
    private let pill = CALayer()
    private var hovering = false {
        didSet { fadePill() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = SpeellPalette.windowBackground.cgColor
        pill.cornerRadius = 2.5
        pill.backgroundColor = NSColor.white.withAlphaComponent(0.35).cgColor
        pill.opacity = 0
        layer?.addSublayer(pill)
    }

    required init?(coder: NSCoder) {
        fatalError("DividerHandleView no se crea desde un coder")
    }

    /// El frame de la pill se ajusta aquí y no en `layout()`: AppKit no pasa
    /// por `layout()` en una vista a la que solo se le setea el frame desde
    /// afuera, y la pill quedaba en 0×0.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Pill vertical, a 4 pt del borde derecho de la franja —más pegada a
        // la sidebar que a la terminal—, cápsula de 5×16.
        pill.frame = CGRect(
            x: newSize.width - 4 - 5,
            y: (newSize.height - 16) / 2,
            width: 5,
            height: 16)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            // `.mouseMoved` además de `.mouseEnteredAndExited`: sin él, el
            // enter no llegaba (medido en macOS 26).
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
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
