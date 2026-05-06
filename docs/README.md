# PromptPanel Documentation

Updated: `2026-05-07`

This documentation set is now part of the public open-source repository. It is intended to let a new maintainer understand, build, verify, release, troubleshoot, and extend PromptPanel without relying on private handoff notes.

PromptPanel is a native, local-first macOS prompt manager and snippet launcher. The key workflow is:

```text
global hotkey -> quick panel -> search -> execute -> clipboard guarantee -> automatic paste when allowed
```

## Start Here

| Document | Purpose |
| --- | --- |
| [Architecture](./架构说明.md) | System shape, layers, dependencies, startup flow, and design boundaries. |
| [Core modules and logic](./关键模块与核心逻辑.md) | Code map, main modules, search, execution, settings, and UI contracts. |
| [Configuration](./配置说明.md) | Settings, environment variables, build flags, storage paths, and permissions. |
| [Deployment](./部署说明.md) | What "deployment" means for a local macOS app, packaging, CI, signing, notarization, and update hosting. |
| [Operations and troubleshooting](./运维与排错指南.md) | Runtime diagnosis, logs, paste failures, database recovery, and rollback thinking. |
| [Maintainer handoff guide](./接手维护指南.md) | First-day maintainer workflow, code map, validation, release, troubleshooting, and extension rules. |
| [Docs/code sync matrix](./文档与代码同步矩阵.md) | Which docs to update for each code, script, config, release, or UI baseline change. |
| [Release and recovery](./生产发布与恢复手册.md) | Release-readiness flow, backup/restore boundary, signing, notarization, and recovery drill. |
| [Regression checklist](./回归清单.md) | Pre-release behavior and compatibility checks. |
| [Compatibility regression log](./兼容性回归记录.md) | Real target-app compatibility samples and paste behavior notes. |
| [Acceptance checklist](./验收清单.md) | UI, migration, release, and runtime acceptance points used during hardening. |
| [Technical decisions](./技术选型.md) | Why PromptPanel uses Swift, AppKit/SwiftUI, SQLite/GRDB, KeyboardShortcuts, and Sparkle. |
| [AI search and discoverability](./ai-search-discoverability.md) | Repository wording, AI-search keywords, and LLM/SEO maintenance rules. |

Chinese-language handoff docs are intentionally kept because the original product definition and maintainer notes are Chinese. The root README and FAQ provide the English public entry layer.

## Repository Entry Points

- [Root README](../README.md): public product overview and build instructions.
- [Chinese README](../README.zh-CN.md): Chinese public product overview.
- [FAQ](../FAQ.md): search-friendly explanations for common user questions.
- [llms.txt](../llms.txt): short machine-readable project index.
- [llms-full.txt](../llms-full.txt): expanded LLM context.
- [PRD](../项目快贴-PRD.md): product scope and permanent non-goals.
- [Contributing](../CONTRIBUTING.md): contribution rules and validation expectations.
- [Security](../SECURITY.md): private reporting and local-data boundaries.

## Current System Facts

- Runtime shape: local macOS desktop app only.
- Source root: `Sources/PromptPanel`.
- Tests: `Tests/PromptPanelTests`.
- UI source of truth: `frontend-draft/`.
- Build and release scripts: `scripts/`.
- CI: `.github/workflows/macos-release-readiness.yml`.
- Local database: `~/Library/Application Support/PromptPanel/promptpanel.db`.
- Logs: `~/Library/Logs/PromptPanel/`.
- Core guarantee: selected content is written to clipboard before automatic paste is attempted.
- Accessibility permission is required only for automatic paste, not for clipboard fallback.

## Documentation Sync Rules

Update docs in the same pull request when these areas change:

| Change area | Documents to update |
| --- | --- |
| Hotkey, panel lifecycle, activation, focus, or quick panel UI | [Architecture](./架构说明.md), [Core modules and logic](./关键模块与核心逻辑.md), [Regression checklist](./回归清单.md) |
| Database, migrations, backup, restore, or storage paths | [Configuration](./配置说明.md), [Operations and troubleshooting](./运维与排错指南.md), [Release and recovery](./生产发布与恢复手册.md) |
| Paste automation, clipboard behavior, permissions, or execution logs | [Core modules and logic](./关键模块与核心逻辑.md), [Operations and troubleshooting](./运维与排错指南.md), [Compatibility regression log](./兼容性回归记录.md) |
| Build, signing, notarization, Sparkle, or GitHub Actions | [Deployment](./部署说明.md), [Release and recovery](./生产发布与恢复手册.md), [Configuration](./配置说明.md) |
| Product positioning, target users, non-goals, or SEO/AI-search wording | [Root README](../README.md), [Chinese README](../README.zh-CN.md), [FAQ](../FAQ.md), [AI search and discoverability](./ai-search-discoverability.md), [llms.txt](../llms.txt), [llms-full.txt](../llms-full.txt) |
| Documentation structure, handoff workflow, or sync policy | [Maintainer handoff guide](./接手维护指南.md), [Docs/code sync matrix](./文档与代码同步矩阵.md), this index |

## First-Day Maintainer Checklist

1. Run `git status --short` to understand local drift.
2. Run `swift build`.
3. Run `swift test` if the host has full XCTest support. If the host lacks `xctest`, use the documented build-only readiness path and say so.
4. Run `./scripts/release-readiness.sh --output-dir /tmp/promptpanel-ready-check` for release-oriented validation.
5. Build the `.app` with `./scripts/build-app.sh` and smoke test the packaged app, not only the command-line binary.
6. Check the main window's Runtime Health and recent execution logs after a real paste test.

## Boundaries To Preserve

- PromptPanel is a local macOS client, not a server product.
- Containers and ordinary servers can host release files, but they do not run the product.
- Clipboard write is the reliability guarantee; automatic paste is a best-effort convenience.
- Database corruption recovery and schema migration failure are different incident classes.
- Cloud sync, team collaboration, and workflow orchestration remain permanent non-goals.
