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

    func testMixedEntriesPreferCurrentProjectWhenSortKeysEqual() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        let currentProject = Project(name: "Current")
        try projectRepository.create(currentProject)

        let now = Date()
        try entryRepository.create(
            Entry(
                projectId: defaultProject.id,
                title: "共享标题",
                content: "通用内容",
                sortOrder: 10,
                useCount: 4,
                lastUsedAt: now,
                createdAt: now,
                updatedAt: now
            )
        )
        try entryRepository.create(
            Entry(
                projectId: currentProject.id,
                title: "共享标题",
                content: "当前内容",
                sortOrder: 10,
                useCount: 4,
                lastUsedAt: now,
                createdAt: now,
                updatedAt: now
            )
        )

        let result = try entryRepository.fetchMixed(
            currentProjectId: currentProject.id,
            defaultProjectId: defaultProject.id
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.projectId, currentProject.id)
        XCTAssertEqual(result.last?.projectId, defaultProject.id)
    }

    func testMigrateAndDeleteMovesEntriesToTargetProject() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

        let sourceProject = Project(name: "Source")
        let targetProject = Project(name: "Target")
        try projectRepository.create(sourceProject)
        try projectRepository.create(targetProject)

        let entry = Entry(projectId: sourceProject.id, title: "Snippet", content: "echo hello")
        try entryRepository.create(entry)

        try projectRepository.migrateAndDelete(fromId: sourceProject.id, toId: targetProject.id)

        XCTAssertNil(try projectRepository.fetchById(sourceProject.id))
        let migratedEntry = try XCTUnwrap(entryRepository.fetchById(entry.id))
        XCTAssertEqual(migratedEntry.projectId, targetProject.id)
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

@Test
func mixedEntriesPreferCurrentProjectWhenSortKeysEqual() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

    let defaultProject = try #require(projectRepository.fetchDefault())
    let currentProject = Project(name: "Current")
    try projectRepository.create(currentProject)

    let now = Date()
    try entryRepository.create(
        Entry(
            projectId: defaultProject.id,
            title: "共享标题",
            content: "通用内容",
            sortOrder: 10,
            useCount: 4,
            lastUsedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )
    try entryRepository.create(
        Entry(
            projectId: currentProject.id,
            title: "共享标题",
            content: "当前内容",
            sortOrder: 10,
            useCount: 4,
            lastUsedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let result = try entryRepository.fetchMixed(
        currentProjectId: currentProject.id,
        defaultProjectId: defaultProject.id
    )

    #expect(result.count == 2)
    #expect(result.first?.projectId == currentProject.id)
    #expect(result.last?.projectId == defaultProject.id)
}

@Test
func migrateAndDeleteMovesEntriesToTargetProject() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

    let sourceProject = Project(name: "Source")
    let targetProject = Project(name: "Target")
    try projectRepository.create(sourceProject)
    try projectRepository.create(targetProject)

    let entry = Entry(projectId: sourceProject.id, title: "Snippet", content: "echo hello")
    try entryRepository.create(entry)

    try projectRepository.migrateAndDelete(fromId: sourceProject.id, toId: targetProject.id)

    #expect(try projectRepository.fetchById(sourceProject.id) == nil)
    let migratedEntry = try #require(entryRepository.fetchById(entry.id))
    #expect(migratedEntry.projectId == targetProject.id)
}
#endif

private func makeDatabaseManager() throws -> DatabaseManager {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")
    return try DatabaseManager(url: databaseURL)
}
