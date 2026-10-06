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

    /// El override lleva el fondo que se le pide; la clave del pin es
    /// `background` (`src/config/Config.zig:605`).
    func testOverrideCarriesTheGivenBackground() throws {
        let url = try XCTUnwrap(
            TerminalPalette.writeOverride(hex: "#0A0B0C", in: directory))
        let contents = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(contents.contains("#0A0B0C"))
        XCTAssertTrue(
            contents.contains("background"),
            "la clave del pin es `background` (`src/config/Config.zig:605`)")
    }

    /// El override se reescribe completo en cada escritura: no crece ni
    /// conserva lo que hubiera de una escritura anterior.
    func testOverrideIsRewrittenNotAppended() throws {
        let url = try XCTUnwrap(
            TerminalPalette.writeOverride(hex: TerminalPalette.backgroundHex, in: directory))

        // Se ensucia el archivo como si una escritura anterior hubiera dejado de más.
        let dirty = try String(contentsOf: url, encoding: .utf8)
            + "\nbackground = #000000\n"
        try dirty.write(to: url, atomically: true, encoding: .utf8)

        let again = try XCTUnwrap(
            TerminalPalette.writeOverride(hex: TerminalPalette.backgroundHex, in: directory))
        let contents = try String(contentsOf: again, encoding: .utf8)

        XCTAssertEqual(contents, "background = \(TerminalPalette.backgroundHex)\n")
        XCTAssertFalse(contents.contains("#000000"))
    }

    /// El fondo vigente es el del override; sin override, el de la spec.
    func testCurrentBackgroundFallsBackToTheSpec() {
        XCTAssertEqual(
            TerminalPalette.backgroundHex(in: directory),
            TerminalPalette.backgroundHex)

        _ = TerminalPalette.writeOverride(hex: "#112233", in: directory)
        XCTAssertEqual(TerminalPalette.backgroundHex(in: directory), "#112233")
    }

    /// No hay test de integración con libghostty a propósito: `ghostty_config_new`
    /// segfaultea dentro del proceso de XCTest, así que cargar el override
    /// contra la C API no es ejecutable en un test unitario. Que el fondo
    /// llegue a la pantalla se verifica corriendo la app, no aquí.
    func testIntegrationWithTheEngineNeedsTheRunningApp() {
        XCTAssertEqual(TerminalPalette.overrideFileName, "ghostty.conf")
    }

    /// El override carga varias claves y se lee como diccionario; escribir el
    /// fondo conserva las demás.
    func testValuesRoundtripAndHexWriteKeepsOtherKeys() throws {
        _ = TerminalPalette.writeOverride(
            values: ["background": "#161616", "font-family": "Menlo", "font-size": "14"],
            in: directory)

        XCTAssertEqual(TerminalPalette.backgroundHex(in: directory), "#161616")
        XCTAssertEqual(TerminalPalette.fontFamily(in: directory), "Menlo")
        XCTAssertEqual(TerminalPalette.fontSize(in: directory), 14)

        _ = TerminalPalette.writeOverride(hex: "#0A0B0C", in: directory)

        XCTAssertEqual(TerminalPalette.backgroundHex(in: directory), "#0A0B0C")
        XCTAssertEqual(TerminalPalette.fontFamily(in: directory), "Menlo")
        XCTAssertEqual(TerminalPalette.fontSize(in: directory), 14)
    }

    /// Sin override, la tipografía es la bundled del CLI y el tamaño, el
    /// default del pin para macOS (13).
    func testFontDefaultsComeFromThePin() {
        XCTAssertNil(TerminalPalette.fontFamily(in: directory))
        XCTAssertEqual(TerminalPalette.fontSize(in: directory), 13)
    }
}
