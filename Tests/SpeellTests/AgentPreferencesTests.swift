import XCTest

@testable import Speell

final class AgentPreferencesTests: XCTestCase {
    func testAgentsDefaultToEnabled() {
        let preferences = AgentPreferences()
        XCTAssertTrue(preferences.isEnabled(.grok))
        XCTAssertTrue(preferences.isEnabled(.opencode2))
        XCTAssertTrue(preferences.isEnabled(.agy))
    }

    func testDisableAndEnableRoundtripThroughCodable() throws {
        var preferences = AgentPreferences()
        preferences.setEnabled(false, for: .agy)

        let data = try JSONEncoder().encode(preferences)
        var back = try JSONDecoder().decode(AgentPreferences.self, from: data)

        XCTAssertFalse(back.isEnabled(.agy), "el estado deshabilitado sobrevive al disco")
        XCTAssertTrue(back.isEnabled(.grok), "los ausentes siguen habilitados")

        back.setEnabled(true, for: .agy)
        XCTAssertTrue(back.isEnabled(.agy))
    }
}

/// El catálogo de monoespaciadas mide; estas dos condiciones deben cumplir en
/// cualquier máquina macOS: no viene vacío y trae las mono del sistema.
final class MonoFontsTests: XCTestCase {
    func testInstalledContainsTheBuiltinMonoFamilies() {
        let fonts = MonoFonts.installed()
        XCTAssertFalse(fonts.isEmpty)
        for builtin in ["Menlo", "Monaco", "Courier New"] {
            XCTAssertTrue(
                fonts.contains(builtin),
                "\(builtin) es mono del sistema y debe estar en el catálogo")
        }
        XCTAssertEqual(fonts, fonts.sorted(), "el catálogo sale alfabético")
    }

    func testProportionalFamiliesAreRejected() {
        XCTAssertFalse(MonoFonts.isMonospace("Times New Roman"))
        XCTAssertFalse(MonoFonts.isMonospace("LastResort"))
    }
}
