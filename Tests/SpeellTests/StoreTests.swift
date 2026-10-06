import XCTest

@testable import Speell

/// Persistencia con un directorio temporal: nunca toca la Application Support
/// del usuario.
final class StoreTests: XCTestCase {
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

    // MARK: Proyectos

    func testProjectsStartEmpty() {
        let projects = ProjectStore(store: store)
        XCTAssertTrue(projects.projects.isEmpty)
        XCTAssertNil(projects.lastActiveProjectId)
    }

    func testAddProjectPersistsPathNameAndIdentity() {
        let added = ProjectStore(store: store).add(path: "/tmp/speell-a")

        let reloaded = ProjectStore(store: store)
        XCTAssertEqual(reloaded.projects.count, 1)
        XCTAssertEqual(reloaded.projects.first?.id, added.id)
        XCTAssertEqual(reloaded.projects.first?.path, "/tmp/speell-a")
        XCTAssertEqual(reloaded.projects.first?.displayName, "speell-a")
    }

    func testAddProjectDoesNotDuplicateAnAlreadyPinnedPath() {
        let projects = ProjectStore(store: store)
        let first = projects.add(path: "/tmp/speell-a")
        let second = projects.add(path: "/tmp/speell-a")

        XCTAssertEqual(projects.projects.count, 1)
        XCTAssertEqual(first.id, second.id)
    }

    func testOrderedPutsTheMostRecentlyActiveProjectFirst() {
        let projects = ProjectStore(store: store)
        let first = projects.add(path: "/tmp/speell-a")
        let second = projects.add(path: "/tmp/speell-b")

        projects.touch(id: first.id)

        XCTAssertEqual(projects.ordered.map(\.id), [first.id, second.id])
        XCTAssertEqual(ProjectStore(store: store).ordered.map(\.id), [first.id, second.id])
    }

    func testRemoveProjectAlsoClearsItAsActive() {
        let projects = ProjectStore(store: store)
        let project = projects.add(path: "/tmp/speell-a")
        projects.setActive(id: project.id)

        projects.remove(id: project.id)

        XCTAssertTrue(projects.projects.isEmpty)
        XCTAssertNil(projects.lastActiveProjectId)
        XCTAssertTrue(ProjectStore(store: store).projects.isEmpty)
    }

    func testSetActivePersistsAcrossRelaunch() {
        let project = ProjectStore(store: store).add(path: "/tmp/speell-a")
        ProjectStore(store: store).setActive(id: project.id)

        XCTAssertEqual(ProjectStore(store: store).lastActiveProjectId, project.id)
    }

    // MARK: Tabs

    func testTabsAreScopedByProjectAndDieWithIt() {
        let sessions = SessionStore(store: store)
        let projectA = UUID()
        let projectB = UUID()
        sessions.add(Tab(projectId: projectA, kind: .shell, cwd: "/tmp/speell-a", title: "speell-a"))
        let shellB = Tab(projectId: projectB, kind: .shell, cwd: "/tmp/speell-b", title: "speell-b")
        sessions.add(shellB)

        XCTAssertEqual(sessions.tabs(of: projectA).count, 1)
        XCTAssertEqual(sessions.tabs(of: projectB).map(\.id), [shellB.id])

        sessions.removeTabs(of: projectA)

        XCTAssertTrue(sessions.tabs(of: projectA).isEmpty)
        XCTAssertEqual(SessionStore(store: store).tabs.map(\.id), [shellB.id])
    }

    func testTabKeepsItsCwdAndSessionPointerAcrossRelaunch() {
        let tab = Tab(
            projectId: UUID(),
            kind: .agent,
            cwd: "/tmp/speell-a",
            title: "grok",
            agent: .grok,
            sessionId: "abc-123",
            resumeQuality: .exact)
        SessionStore(store: store).add(tab)

        let reloaded = SessionStore(store: store).tabs.first
        XCTAssertEqual(reloaded?.id, tab.id)
        XCTAssertEqual(reloaded?.cwd, "/tmp/speell-a")
        XCTAssertEqual(reloaded?.kind, .agent)
        XCTAssertEqual(reloaded?.agent, .grok)
        XCTAssertEqual(reloaded?.sessionId, "abc-123")
        XCTAssertEqual(reloaded?.resumeQuality, .exact)
    }

    func testRemoveTabLeavesTheSiblings() {
        let sessions = SessionStore(store: store)
        let projectId = UUID()
        let first = Tab(projectId: projectId, kind: .shell, cwd: "/tmp/a", title: "a")
        let second = Tab(projectId: projectId, kind: .shell, cwd: "/tmp/a", title: "b")
        sessions.add(first)
        sessions.add(second)

        sessions.remove(id: first.id)

        XCTAssertEqual(sessions.tabs(of: projectId).map(\.id), [second.id])
        XCTAssertEqual(SessionStore(store: store).tabs.map(\.id), [second.id])
    }
}
