import Foundation

/// Qué ejecuta una tab: binario + argumentos + cwd.
/// `executable == nil` es el shell de login del usuario (tab shell).
///
/// El env no entra aquí: libghostty lanza la surface con el entorno del
/// proceso, que ya es el del usuario. Cuando un adaptador necesite variables
/// propias se usará `env_vars` del surface config.
struct Command: Equatable {
    var executable: String?
    var arguments: [String]
    var cwd: String

    static func shell(in cwd: String) -> Command {
        Command(executable: nil, arguments: [], cwd: cwd)
    }

    /// Línea que libghostty le pasa al shell. `nil` para una tab shell.
    var shellLine: String? {
        guard let executable else { return nil }
        return ([executable] + arguments).map(Self.quote).joined(separator: " ")
    }

    private static func quote(_ argument: String) -> String {
        guard !argument.isEmpty else { return "''" }
        let safe = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/:@+=")
        if argument.unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return argument
        }
        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
