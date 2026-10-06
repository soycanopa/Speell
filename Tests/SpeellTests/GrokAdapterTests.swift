import XCTest

@testable import Speell

/// El adaptador se prueba con un binario falso: nada de red y nada de login.
final class GrokAdapterTests: XCTestCase {
    private var workspace: URL!

    override func setUpWithError() throws {
        workspace = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("speell-grok-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workspace)
    }

    /// Salida real de `grok sessions list` (grok 1.0.46), capturada tal cual.
    private static let realOutput = """
    (no label)
    SESSION ID                            CREATED     UPDATED     STATUS      SUMMARY
    019f5191-4164-7f10-ad66-16c5acca2f0a  2026-07-11  2026-07-11  remote  Project Status Review: Current State and Missing T
    019f518f-ff0e-7eb2-91a7-ea5a3db3c1d5  2026-07-11  2026-07-11  remote  Initial Review of Software Project Codebase
    019f097b-4030-7491-bb60-d8fdd19b7baf  2026-06-27  2026-06-27  remote  Analyze Project and Explain Its Purpose

    """

    // MARK: Parser

    func testParsesTheRealListOutput() {
        let sessions = GrokSessionListParser.sessions(from: Self.realOutput)
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].id, "019f5191-4164-7f10-ad66-16c5acca2f0a")
        XCTAssertEqual(sessions[0].title, "Project Status Review: Current State and Missing T")
        XCTAssertEqual(sessions[2].id, "019f097b-4030-7491-bb60-d8fdd19b7baf")
        XCTAssertEqual(sessions[2].title, "Analyze Project and Explain Its Purpose")
        XCTAssertNotNil(sessions[0].updatedAt)
    }

    func testEmptyResultIsNotAnError() {
        XCTAssertTrue(GrokSessionListParser.sessions(from: "No sessions found.\n").isEmpty)
        XCTAssertTrue(GrokSessionListParser.sessions(from: "").isEmpty)
    }

    func testIgnoresHeaderAndJunkLines() {
        let output = """
        ruido
        SESSION ID                            CREATED     UPDATED     STATUS      SUMMARY
        no soy una fila
        019f5191-4164-7f10-ad66-16c5acca2f0a  2026-07-11  2026-07-11  remote
        """
        let sessions = GrokSessionListParser.sessions(from: output)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].title, "sin título")
    }

    // MARK: Adaptador contra el binario

    func testListRunsTheBinaryInTheRequestedDirectory() async throws {
        let cwd = workspace.appendingPathComponent("proyecto").path
        try? FileManager.default.createDirectory(atPath: cwd, withIntermediateDirectories: true)
        let fake = try makeBinary(
            """
            #!/bin/sh
            printf '(no label)\\n'
            printf 'SESSION ID                            CREATED     UPDATED     STATUS      SUMMARY\\n'
            printf '019f5191-4164-7f10-ad66-16c5acca2f0a  2026-07-11  2026-07-11  remote  %s\\n' "$(pwd)"
            """)

        let sessions = await GrokAdapter(executable: fake).list(cwd: cwd)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, "019f5191-4164-7f10-ad66-16c5acca2f0a")
        // El título es el `pwd` del hijo: prueba que corre en el cwd de la tab.
        // Se comparan rutas físicas porque /var y /private/var son el mismo sitio.
        XCTAssertEqual(sessions[0].title, physicalPath(cwd))
    }

    func testListWithABrokenBinaryReturnsNoSessions() async throws {
        let failing = try makeBinary("#!/bin/sh\nexit 1\n")
        let sessions = await GrokAdapter(executable: failing).list(cwd: workspace.path)
        XCTAssertTrue(sessions.isEmpty)

        let missing = await GrokAdapter(executable: "/no/existe/grok").list(cwd: workspace.path)
        XCTAssertTrue(missing.isEmpty)
    }

    // MARK: Comandos

    func testLaunchStartsABareConversation() {
        // El id lo genera grok; Speell no propone nada (docs/decisions/0005).
        let command = GrokAdapter().launch(cwd: "/tmp/p")
        XCTAssertEqual(command.executable, "grok")
        XCTAssertEqual(command.arguments, [])
        XCTAssertEqual(command.cwd, "/tmp/p")
        XCTAssertEqual(command.shellLine, "grok")
    }

    func testResumeAndContinueUseTheVerifiedFlags() {
        let adapter = GrokAdapter()
        XCTAssertEqual(adapter.resume(cwd: "/tmp/p", id: "019f5191-4164-7f10-ad66-16c5acca2f0a").arguments, ["--resume", "019f5191-4164-7f10-ad66-16c5acca2f0a"])
        XCTAssertEqual(adapter.continueLatest(cwd: "/tmp/p").arguments, ["-c"])
        XCTAssertEqual(adapter.kind, .grok)
        XCTAssertEqual(adapter.kind.displayName, "Grok")
    }

    func testShellTabHasNoCommandLine() {
        XCTAssertNil(Command.shell(in: "/tmp/p").shellLine)
    }

    func testShellLineQuotesArguments() {
        let command = Command(executable: "grok", arguments: ["--resume", "id con espacio", "it's"], cwd: "/tmp")
        XCTAssertEqual(command.shellLine, "grok --resume 'id con espacio' 'it'\\''s'")
        XCTAssertEqual(Command(executable: "grok", arguments: [], cwd: "/tmp").shellLine, "grok")
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
