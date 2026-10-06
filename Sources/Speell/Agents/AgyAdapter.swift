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
