import Foundation

/// OpenCode 2 (`opencode2`), binario de opencode v2.0.22. Contrato verificado
/// contra el binario real: `opencode2 --help`, `opencode2 session --help`,
/// `opencode2 session list --help`, el spec OpenAPI del propio binario
/// (`opencode2 api GET /openapi.json`) y una corrida real de `session list
/// --format json`. Ver docs/decisions/0004 y 0005.
struct OpenCode2Adapter: AgentAdapter {
    /// Binario. Inyectable para los tests con un doble.
    var executable = "opencode2"

    var kind: AgentKind { .opencode2 }

    /// El listado pasa por el servicio de fondo del CLI. En frío (sin
    /// servicio) tardó ~75 s en arrancar, medido 2026-10-06; en caliente
    /// responde en <0.1 s. 10 s cubre arranques lentos sin colgar el modal;
    /// si se pasa, `list` devuelve vacío y el modal degrada (FLOW F2).
    private static let listTimeout: TimeInterval = 10

    func list(cwd: String) async -> [SessionRef] {
        let executable = self.executable
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let output = CLIProcess.run(
                    executable: executable,
                    arguments: ["session", "list", "-n", "20", "--format", "json"],
                    cwd: cwd,
                    timeout: Self.listTimeout)
                continuation.resume(returning: output.map(OpenCode2SessionListParser.sessions(from:)) ?? [])
            }
        }
    }

    /// Conversación nueva a secas: el id lo genera opencode2, y son siempre
    /// `ses…` — el CLI rechaza cualquier otro formato con "Expected a string
    /// starting with ses" (docs/decisions/0005).
    func launch(cwd: String) -> Command {
        Command(executable: executable, arguments: [], cwd: cwd)
    }

    /// `--session`: "Session ID to continue, or to create if it does not
    /// exist" (`opencode2 --help`). Solo se le pasan ids que salió de `list`.
    func resume(cwd: String, id: String) -> Command {
        Command(executable: executable, arguments: ["--session", id], cwd: cwd)
    }

    func continueLatest(cwd: String) -> Command {
        Command(executable: executable, arguments: ["--continue"], cwd: cwd)
    }
}
