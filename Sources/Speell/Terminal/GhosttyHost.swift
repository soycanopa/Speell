import AppKit
import GhosttyKit

/// Envuelve el `ghostty_app_t`: config, runtime callbacks y tick.
/// No contiene vistas; la surface vive en `SurfaceView`.
final class GhosttyHost {
    private(set) var app: ghostty_app_t?

    /// La invoca libghostty cuando una surface debe cerrarse, por ejemplo
    /// cuando el proceso hijo terminó.
    var onSurfaceClose: (() -> Void)?

    init() {
        guard let config = Self.loadConfig() else {
            FileHandle.standardError.write(Data("config de libghostty inválida\n".utf8))
            exit(1)
        }
        defer { ghostty_config_free(config) }

        var runtime = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: false,
            wakeup_cb: { userdata in
                guard let userdata else { return }
                let host = Unmanaged<GhosttyHost>.fromOpaque(userdata).takeUnretainedValue()
                DispatchQueue.main.async { host.tick() }
            },
            action_cb: { _, _, _ in false },
            // Sin portapapeles en el spike: libghostty lo trata como no soportado.
            read_clipboard_cb: { _, _, _, _, _, _ in GHOSTTY_CLIPBOARD_READ_UNSUPPORTED },
            confirm_read_clipboard_cb: { _, _, _, _ in },
            write_clipboard_cb: { _, _, _, _, _ in },
            close_surface_cb: { userdata, _ in
                guard let userdata else { return }
                let host = Unmanaged<GhosttyHost>.fromOpaque(userdata).takeUnretainedValue()
                DispatchQueue.main.async { host.onSurfaceClose?() }
            }
        )

        guard let app = ghostty_app_new(&runtime, config) else {
            FileHandle.standardError.write(Data("ghostty_app_new falló\n".utf8))
            exit(1)
        }
        self.app = app
    }

    /// libghostty avisa por `wakeup_cb`; el tick corre en el hilo principal.
    func tick() {
        guard let app else { return }
        ghostty_app_tick(app)
    }

    func setFocus(_ focused: Bool) {
        guard let app else { return }
        ghostty_app_set_focus(app, focused)
    }

    /// Libera libghostty, que termina los procesos hijos de sus surfaces.
    func shutdown() {
        guard let app else { return }
        self.app = nil
        ghostty_app_free(app)
    }

    private static func loadConfig() -> ghostty_config_t? {
        guard let config = ghostty_config_new() else { return nil }
        ghostty_config_load_default_files(config)
        ghostty_config_load_recursive_files(config)
        ghostty_config_finalize(config)

        let count = ghostty_config_diagnostics_count(config)
        for index in 0..<count {
            let message = String(cString: ghostty_config_get_diagnostic(config, index).message)
            FileHandle.standardError.write(Data("config: \(message)\n".utf8))
        }
        return config
    }
}
