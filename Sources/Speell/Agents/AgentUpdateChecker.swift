import Foundation

/// Chequeo e instalación de actualizaciones del CLI de un agente. Solo lo
/// implementan los CLIs que exponen un chequeo documentado; para los demás no
/// hay detección honesta y la UI no ofrece botón (docs/decisions/0004).
protocol AgentUpdateChecking {
    /// Chequea sin instalar. `nil` si el chequeo falla.
    func check() async -> AgentUpdate?
    /// Instala la actualización. `true` si terminó bien.
    func update() async -> Bool
}

/// Resultado de un chequeo de actualización.
struct AgentUpdate: Equatable {
    let current: String
    let latest: String
    let available: Bool
}

/// Grok: `grok update --check --json` chequea sin instalar (grok 1.0.46);
/// `grok update` instala. Salida real del chequeo:
///
///     {"currentVersion":"1.0.46","latestVersion":"1.0.46",
///      "updateAvailable":false,"installer":"internal",
///      "channel":"stable","autoUpdate":true,"error":null}
struct GrokUpdateChecker: AgentUpdateChecking {
    /// Binario. Inyectable para los tests con un doble.
    var executable = "grok"

    func check() async -> AgentUpdate? {
        let executable = self.executable
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let output = CLIProcess.run(
                    executable: executable,
                    arguments: ["update", "--check", "--json"],
                    cwd: NSHomeDirectory(),
                    timeout: 30)
                continuation.resume(returning: output.flatMap(GrokUpdateChecker.parse))
            }
        }
    }

    func update() async -> Bool {
        let executable = self.executable
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let output = CLIProcess.run(
                    executable: executable,
                    arguments: ["update"],
                    cwd: NSHomeDirectory(),
                    timeout: 300)
                continuation.resume(returning: output != nil)
            }
        }
    }

    /// Parseo del JSON del chequeo. Falla → `nil` (el que llama degrada).
    static func parse(_ output: String) -> AgentUpdate? {
        struct Output: Decodable {
            let currentVersion: String
            let latestVersion: String
            let updateAvailable: Bool
        }
        guard let data = output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Output.self, from: data)
        else { return nil }
        return AgentUpdate(
            current: decoded.currentVersion,
            latest: decoded.latestVersion,
            available: decoded.updateAvailable)
    }
}
