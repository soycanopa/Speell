import XCTest

@testable import Speell

/// El adaptador se prueba con un binario falso: nada de red y nada de login.
final class OpenCode2AdapterTests: XCTestCase {
    private var workspace: URL!

    override func setUpWithError() throws {
        workspace = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("speell-opencode2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workspace)
    }

    /// Salida real de `opencode2 session list -n 3 --format json`
    /// (opencode v2.0.22), capturada tal cual el 2026-10-06. Esas sesiones no
    /// tienen título, así que el parser debe degradarlas a "sin título".
    private static let realOutput = """
    [
      {
        "id": "ses_ef927c45cffeFaeiW5COUJ0FqS",
        "updated": 1791116196773,
        "created": 1791116196773,
        "projectId": "e22c0befcd3aab577c593974d56decf884468691",
        "directory": "/"
      },
      {
        "id": "ses_ef927c646ffephgIRJDkgW8b7j",
        "updated": 1791116196285,
        "created": 1791116196285,
        "projectId": "e22c0befcd3aab577c593974d56decf884468691",
        "directory": "/"
      },
      {
        "id": "ses_ef929d0c9ffeigh3pehYJEs5Ou",
        "updated": 1791116062521,
        "created": 1791116062521,
        "projectId": "e22c0befcd3aab577c593974d56decf884468691",
        "directory": "/"
      }
    ]
    """

    // MARK: Parser

    func testParsesTheRealListOutput() {
        let sessions = OpenCode2SessionListParser.sessions(from: Self.realOutput)
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].id, "ses_ef927c45cffeFaeiW5COUJ0FqS")
        XCTAssertEqual(sessions[1].id, "ses_ef927c646ffephgIRJDkgW8b7j")
        // Época en milisegundos: 1791116196773 ms es la misma fecha que
        // `time_updated` del store del CLI para esa sesión.
        XCTAssertEqual(
            sessions[0].updatedAt,
            Date(timeIntervalSince1970: 1_791_116_196.773))
    }

    func testSessionsWithoutTitleDegradeToSinTitulo() {
        let sessions = OpenCode2SessionListParser.sessions(from: Self.realOutput)
        XCTAssertTrue(sessions.allSatisfy { $0.title == "sin título" })
    }

    /// `title` es opcional en `Session.Info` (spec OpenAPI del binario): cuando
    /// viene, es el título de la sesión.
    func testParsesTheOptionalTitle() {
        let output = """
        [
          {
            "id": "ses_abc",
            "title": "Refactor del adaptador",
            "updated": 1791116196773
          },
          {
            "id": "ses_def",
            "title": "",
            "updated": 1791116196773
          }
        ]
        """
        let sessions = OpenCode2SessionListParser.sessions(from: output)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].title, "Refactor del adaptador")
        XCTAssertEqual(sessions[1].title, "sin título")
    }

    func testEmptyAndBrokenOutputAreNotAnError() {
        XCTAssertTrue(OpenCode2SessionListParser.sessions(from: "[]").isEmpty)
        XCTAssertTrue(OpenCode2SessionListParser.sessions(from: "").isEmpty)
        XCTAssertTrue(OpenCode2SessionListParser.sessions(from: "Timed out").isEmpty)
    }

    // MARK: Adaptador contra el binario

    func testListRunsTheBinaryInTheRequestedDirectory() async throws {
        let cwd = workspace.appendingPathComponent("proyecto").path
        try? FileManager.default.createDirectory(atPath: cwd, withIntermediateDirectories: true)
        let fake = try makeBinary(
            """
            #!/bin/sh
            printf '[\\n  {\\n    "id": "ses_abc",\\n    "title": "%s",\\n    "updated": 1791116196773\\n  }\\n]\\n' "$(pwd)"
            """)

        let sessions = await OpenCode2Adapter(executable: fake).list(cwd: cwd)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, "ses_abc")
        // El título es el `pwd` del hijo: prueba que corre en el cwd de la tab.
        // Se comparan rutas físicas porque /var y /private/var son el mismo sitio.
        XCTAssertEqual(sessions[0].title, physicalPath(cwd))
    }

    func testListWithABrokenBinaryReturnsNoSessions() async throws {
        let failing = try makeBinary("#!/bin/sh\nexit 1\n")
        let sessions = await OpenCode2Adapter(executable: failing).list(cwd: workspace.path)
        XCTAssertTrue(sessions.isEmpty)

        let missing = await OpenCode2Adapter(executable: "/no/existe/opencode2").list(cwd: workspace.path)
        XCTAssertTrue(missing.isEmpty)
    }

    // MARK: Comandos

    func testLaunchPinsTheSessionIdWithTheDocumentedFlag() {
        let command = OpenCode2Adapter().launch(cwd: "/tmp/p", sessionId: "ses_abc")
        XCTAssertEqual(command.executable, "opencode2")
        XCTAssertEqual(command.arguments, ["--session", "ses_abc"])
        XCTAssertEqual(command.cwd, "/tmp/p")
    }

    func testResumeUsesTheSameFlagAndLatestUsesContinue() {
        let adapter = OpenCode2Adapter()
        XCTAssertEqual(adapter.resume(cwd: "/tmp/p", id: "ses_abc").arguments, ["--session", "ses_abc"])
        XCTAssertEqual(adapter.continueLatest(cwd: "/tmp/p").arguments, ["--continue"])
        XCTAssertEqual(adapter.kind, .opencode2)
        XCTAssertEqual(adapter.kind.displayName, "OpenCode 2")
        XCTAssertEqual(adapter.canPinSessionId, true)
    }

    // MARK: Doble

    private func makeBinary(_ script: String) throws -> String {
        let url = workspace.appendingPathComponent("fake-\(UUID().uuidString).sh")
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url.path
    }

    /// Ruta sin symlinks (`/var` → `/private/var`), que es lo que imprime `pwd`.
    private func physicalPath(_ path: String) -> String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        return path.withCString { pointer in
            guard realpath(pointer, &buffer) != nil else { return path }
            return String(cString: buffer)
        }
    }
}
