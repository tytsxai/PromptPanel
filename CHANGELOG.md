# Changelog

All notable changes to PromptPanel are tracked here.

The format is based on Keep a Changelog, and this project uses Conventional Commits for commit messages.

## [Unreleased]

### Added

- Add entry use-count levels with visible tier colors in the library and quick panel.
- Add a persisted "by level" library sort mode.
- Add quick-panel pin controls, including a header button and `Command-P` handling while the search field is focused.
- Add persisted quick-panel window origin and settings controls for panel content size.
- Add public project documentation: README files, contribution guide, FAQ, security policy, changelog, license, and issue templates.

### Changed

- Tighten quick-panel row density and improve title/preview truncation.
- Let pointer clicks execute visible quick-panel rows immediately.
- Improve sheet layouts for project, entry, and project-migration flows.
- Delay paste briefly after the target app regains focus to reduce focus-race failures.
- Update the frontend draft to match the denser quick-panel layout.

### Fixed

- Use tracked app icon assets from the README instead of ignored local icon-generation artifacts.
