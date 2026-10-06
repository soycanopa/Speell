import Foundation
import XCTest

@testable import Speell

/// La decisión de FLOW F4: qué hace un aviso según el estado de la app,
/// las preferencias y la clase de la tab. Sin AppKit: decision pura.
final class NoticeRouterTests: XCTestCase {
    private let on = NotificationPreferences()

    private func pref(
        system: Bool = true,
        agentMessages: Bool = true,
        finished: Bool = true,
        failed: Bool = true
    ) -> NotificationPreferences {
        var p = NotificationPreferences()
        p.systemEnabled = system
        p.agentMessages = agentMessages
        p.finished = finished
        p.failed = failed
        return p
    }

    func testBellOnShellTabIsNotANotice() {
        let route = NoticeRouter.route(
            .bell,
            isAgentTab: false,
            appActive: false,
            preferences: on,
            systemAvailable: true)
        XCTAssertEqual(route, NoticeRoute(marksTab: false, postsSystemNotification: false))
    }

    func testBellOnAgentTabMarksAndPostsWhenUnfocused() {
        let route = NoticeRouter.route(
            .bell,
            isAgentTab: true,
            appActive: false,
            preferences: on,
            systemAvailable: true)
        XCTAssertEqual(route, NoticeRoute(marksTab: true, postsSystemNotification: true))
    }

    func testBellOnAgentTabDoesNotPostWhileAppIsActive() {
        let route = NoticeRouter.route(
            .bell,
            isAgentTab: true,
            appActive: true,
            preferences: on,
            systemAvailable: true)
        XCTAssertEqual(route, NoticeRoute(marksTab: true, postsSystemNotification: false))
    }

    func testAgentMessageMarksAlways() {
        let notice = AgentNotice.agentMessage(title: "Grok", body: "permiso")
        let focused = NoticeRouter.route(
            notice, isAgentTab: true, appActive: true, preferences: on, systemAvailable: true)
        let unfocused = NoticeRouter.route(
            notice, isAgentTab: true, appActive: false, preferences: on, systemAvailable: true)
        XCTAssertTrue(focused.marksTab)
        XCTAssertTrue(unfocused.marksTab)
    }

    func testAgentMessagePostsOnlyWhenUnfocusedAndSystemAvailable() {
        let notice = AgentNotice.agentMessage(title: "Grok", body: "permiso")
        XCTAssertTrue(NoticeRouter.route(
            notice, isAgentTab: true, appActive: false, preferences: on, systemAvailable: true)
            .postsSystemNotification)
        XCTAssertFalse(NoticeRouter.route(
            notice, isAgentTab: true, appActive: true, preferences: on, systemAvailable: true)
            .postsSystemNotification)
        XCTAssertFalse(NoticeRouter.route(
            notice, isAgentTab: true, appActive: false, preferences: on, systemAvailable: false)
            .postsSystemNotification)
    }

    func testMasterSwitchOffSilencesSystemNotificationButNotTheDot() {
        let route = NoticeRouter.route(
            AgentNotice.agentMessage(title: "Grok", body: "permiso"),
            isAgentTab: true,
            appActive: false,
            preferences: pref(system: false),
            systemAvailable: true)
        XCTAssertEqual(route, NoticeRoute(marksTab: true, postsSystemNotification: false))
    }

    func testDisabledKindSilencesSystemNotificationButNotTheDot() {
        let route = NoticeRouter.route(
            AgentNotice.agentMessage(title: "Grok", body: "permiso"),
            isAgentTab: true,
            appActive: false,
            preferences: pref(agentMessages: false),
            systemAvailable: true)
        XCTAssertEqual(route, NoticeRoute(marksTab: true, postsSystemNotification: false))
    }

    func testCommandFinishedFailureKindIsFailed() {
        let failed = NoticeRouter.route(
            .commandFinished(exitCode: 2),
            isAgentTab: true,
            appActive: false,
            preferences: pref(failed: false),
            systemAvailable: true)
        XCTAssertEqual(failed, NoticeRoute(marksTab: true, postsSystemNotification: false))

        let finished = NoticeRouter.route(
            .commandFinished(exitCode: 0),
            isAgentTab: true,
            appActive: false,
            preferences: pref(failed: false),
            systemAvailable: true)
        XCTAssertEqual(finished, NoticeRoute(marksTab: true, postsSystemNotification: true))
    }
}
