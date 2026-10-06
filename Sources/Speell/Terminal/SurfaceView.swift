import AppKit
import GhosttyKit

/// Una surface de libghostty dentro de un `NSView`.
/// Responsabilidad única: hospedar la surface, su tamaño, su foco y su entrada.
final class SurfaceView: NSView, NSTextInputClient {
    private let host: GhosttyHost
    private(set) var surface: ghostty_surface_t?

    /// Se llena durante `keyDown` con el texto que produce `interpretKeyEvents`.
    private var keyTextAccumulator: [String]?
    private var markedText = NSMutableAttributedString()

    init(host: GhosttyHost) {
        self.host = host
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        guard let app = host.app else { return }

        var config = ghostty_surface_config_new()
        config.userdata = Unmanaged.passUnretained(self).toOpaque()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(macos: ghostty_platform_macos_s(
            nsview: Unmanaged.passUnretained(self).toOpaque()))
        config.scale_factor = Double(NSScreen.main?.backingScaleFactor ?? 2)
        config.context = GHOSTTY_SURFACE_CONTEXT_WINDOW

        // Fase 0: shell de login en $HOME. Sin comando explícito, libghostty
        // usa el shell por defecto de la config.
        let home = NSHomeDirectory()
        surface = home.withCString { cHome in
            config.working_directory = cHome
            config.command = nil
            return ghostty_surface_new(app, &config)
        }

        if surface == nil {
            FileHandle.standardError.write(Data("no se pudo crear la surface de libghostty\n".utf8))
        }

        updateContentScale()
        updateSurfaceSize()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no existe para esta vista")
    }

    deinit {
        // Liberar la surface mata el proceso hijo de esa surface.
        if let surface {
            ghostty_surface_free(surface)
        }
    }

    // MARK: Foco

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let surface {
            ghostty_surface_set_focus(surface, true)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result, let surface {
            ghostty_surface_set_focus(surface, false)
        }
        return result
    }

    // MARK: Tamaño y pantalla

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let surface else { return }

        if let screen = window?.screen {
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            ghostty_surface_set_display_id(surface, number?.uint32Value ?? 0)
        }
        updateContentScale()
        updateSurfaceSize()
        ghostty_surface_set_occlusion(surface, !(window?.occlusionState.contains(.visible) ?? false))
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateSurfaceSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentScale()
        updateSurfaceSize()
    }

    private func updateSurfaceSize() {
        guard let surface, bounds.width > 0, bounds.height > 0 else { return }
        let scale = backingScaleFactor
        ghostty_surface_set_size(
            surface,
            UInt32(bounds.width * scale),
            UInt32(bounds.height * scale))
    }

    private func updateContentScale() {
        guard let surface else { return }
        let scale = backingScaleFactor
        ghostty_surface_set_content_scale(surface, Double(scale), Double(scale))
    }

    private var backingScaleFactor: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    // MARK: Teclado

    override func keyDown(with event: NSEvent) {
        guard let surface else { return }

        // Command: el menú y los bindings ya tuvieron su oportunidad en
        // `performKeyEquivalent`; el spike no reenvía esos eventos.
        if event.modifierFlags.contains(.command) { return }

        let translationEvent = event.applyingGhosttyTranslationMods(surface: surface)
        let action: ghostty_input_action_e = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS

        keyTextAccumulator = []
        defer { keyTextAccumulator = nil }

        interpretKeyEvents([translationEvent])

        if let accumulated = keyTextAccumulator, !accumulated.isEmpty {
            for text in accumulated {
                _ = keyAction(action, event: event, translationEvent: translationEvent, text: text)
            }
        } else {
            _ = keyAction(
                action,
                event: event,
                translationEvent: translationEvent,
                text: translationEvent.ghosttyCharacters)
        }
    }

    override func keyUp(with event: NSEvent) {
        _ = keyAction(GHOSTTY_ACTION_RELEASE, event: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Atajos con Command: si libghostty los tiene como binding, se
        // consumen aquí; si no, siguen al menú (Cmd+Q, Cmd+H, ...).
        guard event.type == .keyDown,
              event.modifierFlags.contains(.command),
              let surface else { return false }

        let key = event.ghosttyKeyEvent(GHOSTTY_ACTION_PRESS)
        var flags = ghostty_binding_flags_e(0)
        guard ghostty_surface_key_is_binding(surface, key, &flags) else { return false }

        _ = keyAction(GHOSTTY_ACTION_PRESS, event: event, text: event.ghosttyCharacters)
        return true
    }

    @discardableResult
    private func keyAction(
        _ action: ghostty_input_action_e,
        event: NSEvent,
        translationEvent: NSEvent? = nil,
        text: String? = nil
    ) -> Bool {
        guard let surface else { return false }

        var key = event.ghosttyKeyEvent(action, translationMods: translationEvent?.modifierFlags)

        // Los caracteres de control los codifica libghostty; solo se manda
        // texto si no es un único carácter de control.
        if let text, !text.isEmpty, let first = text.utf8.first, first >= 0x20 {
            return text.withCString { pointer in
                key.text = pointer
                return ghostty_surface_key(surface, key)
            }
        }
        return ghostty_surface_key(surface, key)
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        guard let surface else { return }
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_LEFT, event.ghosttyMods)
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface else { return }
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_LEFT, event.ghosttyMods)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let surface else { return }
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_RIGHT, event.ghosttyMods)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let surface else { return }
        _ = ghostty_surface_mouse_button(surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_RIGHT, event.ghosttyMods)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let surface else { return }
        let point = convert(event.locationInWindow, from: nil)
        ghostty_surface_mouse_pos(
            surface,
            Double(point.x),
            Double(bounds.height - point.y),
            event.ghosttyMods)
    }

    override func mouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        ghostty_surface_mouse_scroll(
            surface,
            Double(event.scrollingDeltaX),
            Double(event.scrollingDeltaY),
            Int32(event.hasPreciseScrollingDeltas ? 1 : 0))
    }

    // MARK: NSTextInputClient

    func insertText(_ string: Any, replacementRange: NSRange) {
        guard surface != nil else { return }

        var characters = ""
        switch string {
        case let value as NSAttributedString: characters = value.string
        case let value as String: characters = value
        default: return
        }

        unmarkText()

        if var accumulated = keyTextAccumulator {
            accumulated.append(characters)
            keyTextAccumulator = accumulated
            return
        }

        characters.withCString { pointer in
            ghostty_surface_text(surface, pointer, UInt(characters.utf8.count))
        }
    }

    override func doCommand(by selector: Selector) {
        // Vacío a propósito: evita el beep del sistema por selectores que no
        // manejamos (copiar, mover cursor, etc.).
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        switch string {
        case let value as NSAttributedString:
            markedText = NSMutableAttributedString(attributedString: value)
        case let value as String:
            markedText = NSMutableAttributedString(string: value)
        default:
            return
        }
        syncPreedit()
    }

    func unmarkText() {
        guard markedText.length > 0 else { return }
        markedText = NSMutableAttributedString()
        syncPreedit()
    }

    func selectedRange() -> NSRange {
        NSRange(location: NSNotFound, length: 0)
    }

    func markedRange() -> NSRange {
        markedText.length > 0
            ? NSRange(location: 0, length: markedText.length)
            : NSRange(location: NSNotFound, length: 0)
    }

    func hasMarkedText() -> Bool {
        markedText.length > 0
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let surface, let window else { return .zero }

        var x: Double = 0
        var y: Double = 0
        var width: Double = 0
        var height: Double = 0
        ghostty_surface_ime_point(surface, &x, &y, &width, &height)

        // libghostty usa origen arriba-izquierda; AppKit, abajo-izquierda.
        let rect = NSRect(
            x: x,
            y: frame.height - y,
            width: width,
            height: max(height, 1))
        return window.convertToScreen(convert(rect, to: nil))
    }

    func characterIndex(for point: NSPoint) -> Int {
        0
    }

    private func syncPreedit() {
        guard let surface else { return }
        let text = markedText.string
        if text.isEmpty {
            ghostty_surface_preedit(surface, nil, 0)
            return
        }
        text.withCString { pointer in
            ghostty_surface_preedit(surface, pointer, UInt(text.utf8.count))
        }
    }
}

extension NSEvent {
    /// Aplica los mods de traducción de libghostty (p. ej. option-as-alt) para
    /// componer el texto de un `keyDown`.
    func applyingGhosttyTranslationMods(surface: ghostty_surface_t) -> NSEvent {
        let translated = NSEvent.eventModifierFlags(
            mods: ghostty_surface_key_translation_mods(surface, ghosttyMods))

        var mods = modifierFlags
        for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] {
            if translated.contains(flag) { mods.insert(flag) } else { mods.remove(flag) }
        }
        guard mods != modifierFlags else { return self }

        return NSEvent.keyEvent(
            with: type,
            location: locationInWindow,
            modifierFlags: mods,
            timestamp: timestamp,
            windowNumber: windowNumber,
            context: nil,
            characters: characters(byApplyingModifiers: mods) ?? "",
            charactersIgnoringModifiers: charactersIgnoringModifiers ?? "",
            isARepeat: isARepeat,
            keyCode: keyCode) ?? self
    }
}
