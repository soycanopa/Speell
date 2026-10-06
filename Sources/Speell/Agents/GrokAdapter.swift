import Foundation

/// Grok (`grok`). Contrato verificado contra el binario real antes de escribir
/// nada: `grok --help`, `grok sessions --help`, `grok sessions list --help` y
/// una corrida de `grok sessions list` (grok 1.0.46). Ver docs/decisions/0003.
struct GrokAdapter: AgentAdapter {
    /// Binario. Inyectable para los tests con un doble.
    var executable = "grok"

    var kind: AgentKind { .grok }

    /// `--session-id` crea la conversación con el id propuesto (docs/decisions/0003).
    var canPinSessionId: Bool { true }

    func list(cwd: String) async -> [SessionRef] {
        let executable = self.executable
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let output = CLIProcess.run(
                    executable: executable,
                    arguments: ["sessions", "list", "-n", "20"],
                    cwd: cwd)
                continuation.resume(returning: output.map(GrokSessionListParser.sessions(from:)) ?? [])
            }
        }
    }

    /// `--session-id` solo vale para conversaciones nuevas; el id debe ser un
    /// UUID que no exista ya en el directorio de sesiones de esa carpeta.
    func launch(cwd: String, sessionId: String) -> Command {
        Command(executable: executable, arguments: ["--session-id", sessionId], cwd: cwd)
    }

    func resume(cwd: String, id: String) -> Command {
        Command(executable: executable, arguments: ["--resume", id], cwd: cwd)
    }

    func continueLatest(cwd: String) -> Command {
        Command(executable: executable, arguments: ["-c"], cwd: cwd)
    }
}
