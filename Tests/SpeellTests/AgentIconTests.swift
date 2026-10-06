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

    /// Los tres agentes tienen arte propio; si a alguno le falta el recurso,
    /// el menú se degrada sin avisar y esto lo caza.
    func testEveryAgentHasItsOwnArt() throws {
        for agent in AgentKind.allCases {
            let image = try XCTUnwrap(
                AgentIcon.image(for: agent),
                "falta el svg de \(agent.displayName) en el bundle")
            XCTAssertTrue(image.isTemplate, "el icono debe teñirse con el color del sistema")
        }
    }
}
