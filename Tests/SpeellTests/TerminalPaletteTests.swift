import XCTest

@testable import Speell

final class TerminalPaletteTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("speell-palette-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// El override tiene que llevar el fondo que la spec fija, no el default
    /// del pin (que es `#282C34`, `src/config/Config.zig:605`).
    func testOverrideCarriesTheConfiguredBackground() throws {
        let url = TerminalPalette.writeOverride(in: directory)
        let written = try XCTUnwrap(url)
        let contents = try String(contentsOf: written, encoding: .utf8)

        XCTAssertTrue(
            contents.contains(TerminalPalette.backgroundHex),
            "el override debe imponer el fondo de la spec, no el del pin")
        XCTAssertTrue(
            contents.contains("background"),
            "la clave del pin es `background` (`src/config/Config.zig:605`)")
    }

    /// El override se reescribe en cada arranque, así que no debe crecer ni
    /// quedar con lo que hubiera de una versión anterior.
    func testOverrideIsRewrittenNotAppended() throws {
        let url = try XCTUnwrap(TerminalPalette.writeOverride(in: directory))

        // Se ensucia el archivo como si una versión anterior hubiera escrito de más.
        let dirty = try String(contentsOf: url, encoding: .utf8)
            + "\nbackground = #000000\n"
        try dirty.write(to: url, atomically: true, encoding: .utf8)

        let again = try XCTUnwrap(TerminalPalette.writeOverride(in: directory))
        let contents = try String(contentsOf: again, encoding: .utf8)

        XCTAssertEqual(contents, TerminalPalette.overrideContents)
        XCTAssertFalse(contents.contains("#000000"))
    }

    /// No hay test de integración con libghostty a propósito: `ghostty_config_new`
    /// segfaultea dentro del proceso de XCTest, así que cargar el override
    /// contra la C API no es ejecutable en un test unitario. Que el fondo
    /// llegue a la pantalla se verifica corriendo la app, no aquí.
    func testIntegrationWithTheEngineNeedsTheRunningApp() {
        XCTAssertEqual(TerminalPalette.overrideFileName, "ghostty.conf")
    }
}