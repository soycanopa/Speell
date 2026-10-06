import Foundation

/// Ejecuta un CLI y captura su salida, con timeout.
/// No hereda el env completo: PATH, HOME y lo que el CLI necesita para
/// arrancar (TRD, Seguridad). No se loguea el env.
enum CLIProcess {
    private static let allowedEnvironment = [
        "PATH", "HOME", "USER", "SHELL", "LANG", "LC_ALL", "TERM", "TMPDIR",
    ]

    /// Devuelve stdout, o `nil` si el binario no existe, falla o se pasa del timeout.
    static func run(
        executable: String,
        arguments: [String],
        cwd: String,
        timeout: TimeInterval = 4
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let inherited = ProcessInfo.processInfo.environment
        var environment = [String: String]()
        for key in allowedEnvironment {
            if let value = inherited[key] { environment[key] = value }
        }
        process.environment = environment

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        // Leer en paralelo: si la salida desborda el buffer del pipe, esperar al
        // proceso antes de leer lo deja colgado.
        let reading = DispatchQueue(label: "speell.cli.stdout")
        var output = Data()
        reading.async { output = stdout.fileHandleForReading.readDataToEndOfFile() }

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }

        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return nil
        }
        reading.sync {}

        guard process.terminationStatus == 0 else { return nil }
        return String(data: output, encoding: .utf8)
    }
}
