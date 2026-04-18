import Foundation

/// Search service for entries: handles FTS search, mixed project results, and PRD-compliant sorting.
@MainActor
final class EntrySearchService {

    private let entryRepository: EntryRepository
    private let appState: AppState

    init(entryRepository: EntryRepository, appState: AppState) {
        self.entryRepository = entryRepository
        self.appState = appState
    }

    /// Search entries for the current project + default project.
    /// Empty query returns all entries (no filter).
    func search(query: String) throws -> [Entry] {
        let currentId = appState.effectiveProjectId
        let defaultId = appState.defaultProjectId ?? ""

        if currentId == defaultId {
            // Current project IS the default project — just show default entries
            if query.isEmpty {
                return try entryRepository.fetchByProject(currentId)
            } else {
                return try entryRepository.search(query: query, currentProjectId: currentId, defaultProjectId: defaultId)
            }
        }

        if query.isEmpty {
            return try entryRepository.fetchMixed(currentProjectId: currentId, defaultProjectId: defaultId)
        } else {
            return try entryRepository.search(query: query, currentProjectId: currentId, defaultProjectId: defaultId)
        }
    }
}
