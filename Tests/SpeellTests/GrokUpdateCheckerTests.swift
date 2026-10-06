import XCTest

@testable import Speell

/// El chequeo de grok se prueba con un binario falso: nada de red.
final class GrokUpdateCheckerTests: XCTestCase {
    private var workspace: URL!

    override func setUpWithError() throws {
        workspace = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("speell-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workspace)
    }

    /// Salida real de `grok update --check --json` (grok 1.0.46), capturada
    /// tal cual con el binario al día.
    private static let upToDateOutput = """
    {"currentVersion":"1.0.46","latestVersion":"1.0.46","updateAvailable":false,"installer":"internal","channel":"stable","autoUpdate":true,"error":null}
    """

    func testParsesTheRealCheckOutput() {
        let update = GrokUpdateChecker.parse(Self.upToDateOutput)
        XCTAssertEqual(update, AgentUpdate(current: "1.0.46", latest: "1.0.46", available: false))
    }

    func testParsesAnAvailableUpdate() {
        let update = GrokUpdateChecker.parse(
            #"{"currentVersion":"1.0.46","latestVersion":"1.0.50","updateAvailable":true,"error":null}"#)
        XCTAssertEqual(update, AgentUpdate(current: "1.0.46", latest: "1.0.50", available: true))
    }

    func testBrokenOutputParsesToNil() {
        XCTAssertNil(GrokUpdateChecker.parse(""))
        XCTAssertNil(GrokUpdateChecker.parse("not json"))
    }

    func testCheckRunsTheBinaryAndParsesItsOutput() async throws {
        let fake = try makeBinary(
            """
            #!/bin/sh
            if [ "$1" = "update" ] && [ "$2" = "--check" ] && [ "$3" = "--json" ]; then
              printf '{"currentVersion":"1.0.1","latestVersion":"1.0.2","updateAvailable":true,"error":null}'
            fi
            """)
        let update = await GrokUpdateChecker(executable: fake).check()
        XCTAssertEqual(update, AgentUpdate(current: "1.0.1", latest: "1.0.2", available: true))
    }

    private func makeBinary(_ script: String) throws -> String {
        let url = workspace.appendingPathComponent("fake-\(UUID().uuidString).sh")
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url.path
    }
}
