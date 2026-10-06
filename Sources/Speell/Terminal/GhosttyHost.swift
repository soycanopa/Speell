import AppKit
import GhosttyKit

/// Envuelve el `ghostty_app_t`: config, runtime callbacks y tick.
/// No contiene vistas; la surface vive en `SurfaceView`.
final class GhosttyHost {
    private(set) var app: ghostty_app_t?

    /// Aviso emitido por una surface (OSC del CLI o fin del comando). Lo
    /// cablea el composition root: el host no conoce tabs ni notificaciones.
    var onSurfaceNotice: ((ghostty_surface_t, AgentNotice) -> Void)?

    /// Dispatch de acciones de libghostty en el hilo del callback. Maneja las
    /// que Speell traduce a avisos; el resto cae al default del runtime.
    fileprivate func handleAction(target: ghostty_target_s, action: ghostty_action_s) -> Bool {
        switch action.tag {
        case GHOSTTY_ACTION_DESKTOP_NOTIFICATION:
            // OSC 9/777 del programa corriendo en la surface. Los strings son
            // del callback: se copian antes de devolver.
            let notification = action.action.desktop_notification
            guard let title = notification.title, let body = notification.body else {
                return true
            }
            dispatch(target, .agentMessage(
                title: String(cString: title),
                body: String(cString: body)))
            return true

        case GHOSTTY_ACTION_COMMAND_FINISHED:
            dispatch(target, .commandFinished(exitCode: Int(action.action.command_finished.exit_code)))
            return true

        default:
            return false
        }
    }

    private func dispatch(_ target: ghostty_target_s, _ notice: AgentNotice) {
        guard target.tag == GHOSTTY_TARGET_SURFACE else { return }
        // El callback corre en el hilo principal (libghostty es síncrono ahí),
        // así que el dispatch no necesita salto.
        onSurfaceNotice?(target.target.surface, notice)
    }

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
                // App-scoped: libghostty pasa el userdata del runtime.
                guard let userdata else { return }
                let host = Unmanaged<GhosttyHost>.fromOpaque(userdata).takeUnretainedValue()
                DispatchQueue.main.async { host.tick() }
            },
            action_cb: { app, target, action in
                // El userdata del app es el mismo del runtime: el host.
                guard let userdata = ghostty_app_userdata(app) else { return false }
                let host = Unmanaged<GhosttyHost>.fromOpaque(userdata).takeUnretainedValue()
                return host.handleAction(target: target, action: action)
            },
            // Sin portapapeles en v1: libghostty lo trata como no soportado.
            read_clipboard_cb: { _, _, _, _, _, _ in GHOSTTY_CLIPBOARD_READ_UNSUPPORTED },
            confirm_read_clipboard_cb: { _, _, _, _ in },
            write_clipboard_cb: { _, _, _, _, _ in },
            close_surface_cb: { userdata, _ in
                // Surface-scoped: el userdata es el `SurfaceView` de la surface.
                guard let userdata else { return }
                let view = Unmanaged<SurfaceView>.fromOpaque(userdata).takeUnretainedValue()
                DispatchQueue.main.async { view.onCloseRequest?() }
            }
        )

        guard let app = ghostty_app_new(&runtime, config) else {
            FileHandle.standardError.write(Data("ghostty_app_new falló\n".utf8))
            exit(1)
        }
        self.app = app
    }

    /// Reconstruye la config (config del usuario + override del palette) y la
    /// aplica a las surfaces dadas. Es el camino del cambio de fondo en vivo
    /// desde la configuración: no hay setter de color en el C API, solo
    /// config nueva sobre la surface.
    func refreshConfig(on surfaces: [ghostty_surface_t]) {
        guard let config = Self.loadConfig() else { return }
        defer { ghostty_config_free(config) }
        for surface in surfaces {
            ghostty_surface_update_config(surface, config)
        }
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
        // El fondo que Speell impone va entre la config del usuario y el
        // finalize: si fuera antes, lo sobrescriben los archivos del usuario.
        TerminalPalette.apply(to: config, in: TerminalPalette.applicationSupportDirectory)
        ghostty_config_finalize(config)

        let count = ghostty_config_diagnostics_count(config)
        for index in 0..<count {
            let message = String(cString: ghostty_config_get_diagnostic(config, index).message)
            FileHandle.standardError.write(Data("config: \(message)\n".utf8))
        }
        return config
    }
}
