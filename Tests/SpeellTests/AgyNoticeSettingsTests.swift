import Foundation
import XCTest

@testable import Speell

/// El merge conservador de la clave documentada `notifications` del
/// `settings.json` de Agy: el archivo es config de otro producto, así que
/// nada de lo que el usuario tenga ahí puede perderse (docs/decisions/0006).
final class AgyNoticeSettingsTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("speell-agy-settings-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testMissingFileMeansDisabled() {
        XCTAssertFalse(AgyNoticeSettings.isEnabled(fileURL: fileURL))
    }

    func testEnableCreatesFileWithJustTheKey() throws {
        try AgyNoticeSettings.enable(fileURL: fileURL)
        XCTAssertTrue(AgyNoticeSettings.isEnabled(fileURL: fileURL))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL))
        let dictionary = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary["notifications"] as? Bool, true)
    }

    func testEnablePreservesTheRestOfTheFile() throws {
        let original = """
        {
          "model": "Gemini 3.8 Flash (Medium)",
          "trustedWorkspaces": ["/Volumes/Masa/Projects/Mac/Speell"]
        }
        """
        try Data(original.utf8).write(to: fileURL)

        try AgyNoticeSettings.enable(fileURL: fileURL)

        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL))
        let dictionary = try XCTUnwrap(object as? [String: Any])
        XCTAssertEqual(dictionary["notifications"] as? Bool, true)
        XCTAssertEqual(dictionary["model"] as? String, "Gemini 3.8 Flash (Medium)")
        XCTAssertEqual(
            dictionary["trustedWorkspaces"] as? [String],
            ["/Volumes/Masa/Projects/Mac/Speell"])
    }

    func testEnableIsIdempotent() throws {
        try AgyNoticeSettings.enable(fileURL: fileURL)
        try AgyNoticeSettings.enable(fileURL: fileURL)
        XCTAssertTrue(AgyNoticeSettings.isEnabled(fileURL: fileURL))
    }

    func testExplicitFalseMeansDisabled() throws {
        try Data("{\"notifications\": false}".utf8).write(to: fileURL)
        XCTAssertFalse(AgyNoticeSettings.isEnabled(fileURL: fileURL))
    }

    func testNonBooleanValueIsNotEnabled() throws {
        try Data("{\"notifications\": \"yes\"}".utf8).write(to: fileURL)
        XCTAssertFalse(AgyNoticeSettings.isEnabled(fileURL: fileURL))
    }
}
