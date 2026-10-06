import AppKit
import GhosttyKit

/// Entrada de la app. libghostty exige inicializar su estado global una sola vez,
/// antes de cualquier otra llamada al C API (ver macos/Sources/App/macOS/main.swift
/// del pin de Ghostty).
@main
@MainActor
enum SpeellApp {
    private static let delegate = AppDelegate()

    static func main() {
        guard ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) == GHOSTTY_SUCCESS else {
            FileHandle.standardError.write(Data("ghostty_init falló\n".utf8))
            exit(1)
        }

        let application = NSApplication.shared
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }
}
