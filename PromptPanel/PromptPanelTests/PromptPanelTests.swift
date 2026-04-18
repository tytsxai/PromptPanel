import Foundation
@testable import PromptPanel

#if canImport(XCTest)
import XCTest

final class PromptPanelTests: XCTestCase {
    func testConstantsExist() {
        XCTAssertEqual(Constants.appName, "PromptPanel")
        XCTAssertEqual(Constants.bundleIdentifier, "com.promptpanel.app")
        XCTAssertEqual(Constants.defaultProjectName, "通用项目")
    }

    func testDatabaseSeedsDefaultProjectAndCurrentProject() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)

        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        XCTAssertEqual(defaultProject.name, Constants.defaultProjectName)
        XCTAssertEqual(try settingsRepository.getCurrentProjectId(), defaultProject.id)
    }
}

#elseif canImport(Testing)
import Testing

@Test
func constantsExist() {
    #expect(Constants.appName == "PromptPanel")
    #expect(Constants.bundleIdentifier == "com.promptpanel.app")
    #expect(Constants.defaultProjectName == "通用项目")
}

@Test
func databaseSeedsDefaultProjectAndCurrentProject() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)

    let defaultProject = try #require(projectRepository.fetchDefault())
    #expect(defaultProject.name == Constants.defaultProjectName)
    #expect(try settingsRepository.getCurrentProjectId() == defaultProject.id)
}
#endif

private func makeDatabaseManager() throws -> DatabaseManager {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")
    return try DatabaseManager(url: databaseURL)
}
