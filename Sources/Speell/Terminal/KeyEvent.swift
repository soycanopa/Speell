import AppKit
import GhosttyKit

extension NSEvent {
    /// Flags de macOS → mods de Ghostty, incluidas las variantes derechas.
    var ghosttyMods: ghostty_input_mods_e {
        var mods = GHOSTTY_MODS_NONE.rawValue
        if modifierFlags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if modifierFlags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if modifierFlags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if modifierFlags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if modifierFlags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }
        if modifierFlags.contains(.numericPad) { mods |= GHOSTTY_MODS_NUM.rawValue }

        let raw = modifierFlags.rawValue
        if raw & UInt(NX_DEVICERSHIFTKEYMASK) != 0 { mods |= GHOSTTY_MODS_SHIFT_RIGHT.rawValue }
        if raw & UInt(NX_DEVICERCTLKEYMASK) != 0 { mods |= GHOSTTY_MODS_CTRL_RIGHT.rawValue }
        if raw & UInt(NX_DEVICERALTKEYMASK) != 0 { mods |= GHOSTTY_MODS_ALT_RIGHT.rawValue }
        if raw & UInt(NX_DEVICERCMDKEYMASK) != 0 { mods |= GHOSTTY_MODS_SUPER_RIGHT.rawValue }

        return ghostty_input_mods_e(mods)
    }

    /// Construye el evento de teclado para libghostty. No setea `text` ni
    /// `composing`: sus lifetimes los maneja quien llama.
    func ghosttyKeyEvent(
        _ action: ghostty_input_action_e,
        translationMods: NSEvent.ModifierFlags? = nil
    ) -> ghostty_input_key_s {
        var key = ghostty_input_key_s()
        key.action = action
        key.keycode = UInt32(keyCode)
        key.text = nil
        key.composing = false
        key.mods = ghosttyMods
        // Control y Command no contribuyen a la traducción de texto; el resto
        // se asume consumido (heurística de la app de Ghostty, ver NSEvent+Extension.swift).
        key.consumed_mods = NSEvent.ghosttyMods(
            (translationMods ?? modifierFlags).subtracting([.control, .command]))

        // Codepoint sin modificadores. `byApplyingModifiers` y no
        // `charactersIgnoringModifiers`, que cambia de comportamiento con Ctrl.
        key.unshifted_codepoint = 0
        if type == .keyDown || type == .keyUp,
           let characters = characters(byApplyingModifiers: []),
           let scalar = characters.unicodeScalars.first {
            key.unshifted_codepoint = scalar.value
        }
        return key
    }

    /// Texto a enviar a libghostty. Filtra caracteres de control (libghostty
    /// los codifica él mismo) y el rango PUA de las teclas de función.
    var ghosttyCharacters: String? {
        guard let characters else { return nil }
        if characters.count == 1, let scalar = characters.unicodeScalars.first {
            if scalar.value < 0x20 {
                return self.characters(byApplyingModifiers: modifierFlags.subtracting(.control))
            }
            if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
                return nil
            }
        }
        return characters
    }

    static func ghosttyMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var mods = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(mods)
    }

    static func eventModifierFlags(mods: ghostty_input_mods_e) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if mods.rawValue & GHOSTTY_MODS_SHIFT.rawValue != 0 { flags.insert(.shift) }
        if mods.rawValue & GHOSTTY_MODS_CTRL.rawValue != 0 { flags.insert(.control) }
        if mods.rawValue & GHOSTTY_MODS_ALT.rawValue != 0 { flags.insert(.option) }
        if mods.rawValue & GHOSTTY_MODS_SUPER.rawValue != 0 { flags.insert(.command) }
        return flags
    }
}
