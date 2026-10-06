import Foundation
import XCTest

@testable import Speell

/// Archivar, recuperar y renombrar proyectos, con persistencia en un
/// directorio temporal. Nunca toca la Application Support del usuario.
final class ProjectArchiveTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("speell-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var store: JSONStore {
        JSONStore(directory: directory)
    }

    func testArchiveKeepsTheProjectOutOfTheSidebarButRecoverable() throws {
        let projects = ProjectStore(store: store)
        let project = projects.add(path: "/tmp/speell-arch")

        projects.archive(id: project.id)
        XCTAssertTrue(try XCTUnwrap(projects.project(id: project.id)).archived)
        XCTAssertTrue(projects.unarchived.isEmpty)
        XCTAssertEqual(projects.archived.map(\.id), [project.id])

        let reloaded = ProjectStore(store: store)
        XCTAssertTrue(try XCTUnwrap(reloaded.project(id: project.id)).archived)

        reloaded.restore(id: project.id)
        XCTAssertFalse(try XCTUnwrap(reloaded.project(id: project.id)).archived)
        XCTAssertEqual(reloaded.unarchived.map(\.id), [project.id])
    }

    func testArchiveIsIdempotentAndRestoreOnlyRevivesArchivedRows() throws {
        let projects = ProjectStore(store: store)
        let project = projects.add(path: "/tmp/speell-arch")

        projects.archive(id: project.id)
        projects.archive(id: project.id)
        XCTAssertTrue(try XCTUnwrap(projects.project(id: project.id)).archived)

        projects.restore(id: project.id)
        projects.restore(id: project.id)
        XCTAssertFalse(try XCTUnwrap(projects.project(id: project.id)).archived)
    }

    /// El JSON previo no traía la clave `archived`: si la decodificación la
    /// exigiera, abrir Speell borraría todos los proyectos del usuario.
    func testDecodingOldJSONWithoutTheArchivedKeyDefaultsToFalse() throws {
        let legacy = """
        {
          "projects": [
            {
              "id": "D5A8A90E-90A7-4F5B-9D63-9C9B7A0A1111",
              "path": "/tmp/speell-viejo",
              "displayName": "speell-viejo",
              "lastActiveAt": "2026-10-06T12:00:00Z"
            }
          ],
          "lastActiveProjectId": "D5A8A90E-90A7-4F5B-9D63-9C9B7A0A1111"
        }
        """
        try Data(legacy.utf8).write(
            to: directory.appendingPathComponent("projects.json"))

        let projects = ProjectStore(store: store)
        let id = try XCTUnwrap(UUID(uuidString: "D5A8A90E-90A7-4F5B-9D63-9C9B7A0A1111"))
        let project = try XCTUnwrap(projects.project(id: id))
        XCTAssertFalse(project.archived)
        XCTAssertEqual(projects.unarchived.count, 1)
    }

    func testRenameChangesOnlyTheDisplayName() throws {
        let projects = ProjectStore(store: store)
        let project = projects.add(path: "/tmp/speell-ren")

        projects.rename(id: project.id, name: "  Masa  ")
        XCTAssertEqual(try XCTUnwrap(projects.project(id: project.id)).displayName, "Masa")
        XCTAssertEqual(try XCTUnwrap(projects.project(id: project.id)).path, "/tmp/speell-ren")

        let reloaded = ProjectStore(store: store)
        XCTAssertEqual(try XCTUnwrap(reloaded.project(id: project.id)).displayName, "Masa")
    }

    func testRenameIgnoresBlankNamesAndUnknownIds() throws {
        let projects = ProjectStore(store: store)
        let project = projects.add(path: "/tmp/speell-ren")

        projects.rename(id: project.id, name: "   ")
        XCTAssertEqual(try XCTUnwrap(projects.project(id: project.id)).displayName, "speell-ren")

        projects.rename(id: UUID(), name: "fantasma")
        XCTAssertEqual(projects.projects.count, 1)
    }

    /// Volver a fijar una carpeta archivada la recupera: no nace una fila
    /// doble ni queda invisible.
    func testAddingAnArchivedPathRestoresIt() throws {
        let projects = ProjectStore(store: store)
        let project = projects.add(path: "/tmp/speell-arch")
        projects.archive(id: project.id)

        let same = projects.add(path: "/tmp/speell-arch")
        XCTAssertEqual(same.id, project.id)
        XCTAssertFalse(try XCTUnwrap(projects.project(id: project.id)).archived)
    }

    func testArchivingTheActiveProjectClearsLastActive() throws {
        let projects = ProjectStore(store: store)
        let project = projects.add(path: "/tmp/speell-arch")
        projects.setActive(id: project.id)

        projects.archive(id: project.id)
        XCTAssertNil(projects.lastActiveProjectId)
    }
}
