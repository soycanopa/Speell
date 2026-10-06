import Foundation

/// Agy (`agy`). Contrato verificado contra el binario real: `agy --help`
/// (2026-10-06). El CLI no tiene subcomando de sesiones ni flag para fijar el
/// id de una conversación nueva, así que el adaptador degrada de forma
/// declarada y nada lee archivos por fuera del CLI:
///
/// - `list` es siempre vacío: no hay listado estable. El modal queda en
///   "sesión nueva" (FLOW F2).
/// - `launch` abre conversación nueva a secas: el id lo genera agy
///   (docs/decisions/0005). Al restaurar la tab pasa a "último de la
///   carpeta" (FLOW F3).
/// - `resume` usa `--conversation`: "Resume a previous conversation by ID".
/// - `continueLatest` usa `--continue`: "Continue the most recent conversation".
struct AgyAdapter: AgentAdapter {
    /// Binario. Inyectable para los tests con un doble.
    var executable = "agy"

    var kind: AgentKind { .agy }

    /// Campana del terminal: los docs de Antigravity documentan la clave
    /// `notifications` de `~/.gemini/antigravity-cli/settings.json` — "system
    /// desktop notification and a terminal bell chime when a long-running
    /// task completes or requires your attention". Default `false`: la
    /// activación es una acción del usuario desde la configuración.
    var noticeSource: NoticeSource { .bell }

    func list(cwd: String) async -> [SessionRef] { [] }

    func launch(cwd: String) -> Command {
        Command(executable: executable, arguments: [], cwd: cwd)
    }

    func resume(cwd: String, id: String) -> Command {
        Command(executable: executable, arguments: ["--conversation", id], cwd: cwd)
    }

    func continueLatest(cwd: String) -> Command {
        Command(executable: executable, arguments: ["--continue"], cwd: cwd)
    }
}
