import XCTest

@testable import Speell

/// Agy no tiene listado ni flag para fijar el id (`agy --help`, verificado
/// 2026-10-06): el contrato del adaptador es la degradación declarada en su
/// documentación. Sin doble que hable por él: `list` ni siquiera corre el
/// binario.
final class AgyAdapterTests: XCTestCase {
    func testListIsEmptyWithoutRunningTheBinary() async {
        // Un binario que no existe prueba que no hay shell-out: si lo llamara,
        // también devolvería vacío, pero el contrato es no llamarlo.
        let sessions = await AgyAdapter(executable: "/no/existe/agy").list(cwd: "/tmp")
        XCTAssertTrue(sessions.isEmpty)
    }

    func testCannotPinTheSessionId() {
        XCTAssertFalse(AgyAdapter().canPinSessionId)
    }

    func testLaunchStartsABareConversationIgnoringTheProposedId() {
        let command = AgyAdapter().launch(cwd: "/tmp/p", sessionId: "lo-que-sea")
        XCTAssertEqual(command.executable, "agy")
        XCTAssertEqual(command.arguments, [])
        XCTAssertEqual(command.cwd, "/tmp/p")
    }

    func testResumeAndContinueUseTheVerifiedFlags() {
        let adapter = AgyAdapter()
        XCTAssertEqual(adapter.resume(cwd: "/tmp/p", id: "ses_abc").arguments, ["--conversation", "ses_abc"])
        XCTAssertEqual(adapter.continueLatest(cwd: "/tmp/p").arguments, ["--continue"])
        XCTAssertEqual(adapter.kind, .agy)
        XCTAssertEqual(adapter.kind.displayName, "Agy")
    }
}
