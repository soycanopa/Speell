import Foundation

/// Grok (`grok`). Contrato verificado contra el binario real antes de escribir
/// nada: `grok --help`, `grok sessions --help`, `grok sessions list --help` y
/// una corrida de `grok sessions list` (grok 1.0.46). Ver docs/decisions/0003
/// y 0005.
struct GrokAdapter: AgentAdapter {
    /// Binario. Inyectable para los tests con un doble.
    var executable = "grok"

    var kind: AgentKind { .grok }

    /// OSC 9/777: el manual embebido del binario (`~/.grok/docs/user-guide/
    /// 05-configuration.md`) documenta `[ui.notifications]`, que dispara
    /// protocolos de notificación del terminal con default `method = "auto"`
    /// y la matriz Ghostty → OSC 777. El pin inyecta `TERM_PROGRAM=ghostty`
    /// (termio/Exec.zig), así que grok detecta Ghostty dentro de Speell.
    /// No hace falta escribir config: los defaults ya emiten.
    var noticeSource: NoticeSource { .osc }

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

    /// Conversación nueva a secas: el id lo genera grok (docs/decisions/0005).
    func launch(cwd: String) -> Command {
        Command(executable: executable, arguments: [], cwd: cwd)
    }

    func resume(cwd: String, id: String) -> Command {
        Command(executable: executable, arguments: ["--resume", id], cwd: cwd)
    }

    func continueLatest(cwd: String) -> Command {
        Command(executable: executable, arguments: ["-c"], cwd: cwd)
    }
}
