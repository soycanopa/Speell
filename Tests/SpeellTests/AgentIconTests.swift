import AppKit
import XCTest

@testable import Speell

/// Los iconos de agente son recursos del bundle: si la ruta cambia, el menú
/// caería al glifo genérico sin avisar. Esto lo caza.
final class AgentIconTests: XCTestCase {
    func testGrokIconLoadsFromTheBundle() throws {
        let image = try XCTUnwrap(
            AgentIcon.image(for: .grok),
            "no se encontró el svg de Grok en el bundle")
        XCTAssertTrue(image.isTemplate, "el icono debe teñirse con el color del sistema")
    }

    func testAgentsWithoutTheirOwnArtReturnNothing() {
        XCTAssertNil(AgentIcon.image(for: .opencode2))
        XCTAssertNil(AgentIcon.image(for: .agy))
    }
}
