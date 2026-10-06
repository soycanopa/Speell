import AppKit
import GhosttyKit

// libghostty exige inicializar su estado global una sola vez, antes de
// cualquier otra llamada al C API (ver macos/Sources/App/macOS/main.swift
// del pin de Ghostty).
guard ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv) == GHOSTTY_SUCCESS else {
    FileHandle.standardError.write(Data("ghostty_init falló\n".utf8))
    exit(1)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
