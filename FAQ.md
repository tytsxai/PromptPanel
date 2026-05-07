# PromptPanel FAQ

## Is PromptPanel free?

Yes. PromptPanel is licensed under MIT. There is no account, paid tier, usage cap, or cloud service required for the core app.

## Where is my data stored?

PromptPanel stores its primary SQLite database at:

```text
~/Library/Application Support/PromptPanel/promptpanel.db
```

Runtime logs are written under:

```text
~/Library/Logs/PromptPanel
```

Both locations can be isolated for QA with the environment variables documented in `docs/配置说明.md`.

## Does PromptPanel upload prompt content?

No. Core prompt storage, search, execution, and logging are local. Network access is limited to Sparkle update checks when update metadata is configured and enabled.

## Is PromptPanel a ChatGPT prompt manager or Claude prompt library?

Yes. PromptPanel is designed for reusable prompts, snippets, templates, and project context blocks that you paste into ChatGPT, Claude, Cursor, Copilot, VS Code, Terminal, browsers, and ordinary macOS text fields. See `docs/使用示例.md` for concrete examples.

## Is PromptPanel a TextExpander, Espanso, or Raycast Snippets alternative?

It overlaps with those tools but is narrower: PromptPanel is a keyboard-first searchable panel for AI prompts and snippets. It is not a general text expansion engine, app launcher, or workflow automation platform.

## Why does PromptPanel need Accessibility permission?

Accessibility permission lets PromptPanel synthesize `Command-V` after it restores focus to the target app. Without it, PromptPanel still writes the selected entry to the clipboard and asks the user to paste manually.

## What happens if auto-paste fails?

The clipboard write happens first and is treated as the durable fallback. If paste cannot be dispatched or the target app does not regain focus, PromptPanel records the failure reason in the execution log and leaves the content on the clipboard.

## Can I sync prompts through the cloud or use teams?

No. Cloud sync, team collaboration, and complex workflow orchestration are permanent non-goals in `项目快贴-PRD.md`. PromptPanel is intentionally single-user and local-first.

## Does PromptPanel have a public API?

No HTTP, cloud, GraphQL, plugin, or remote execution API exists today. The documented "API" surface is the local feature contract, Swift service boundaries, SQLite schema, script interfaces, and environment variables in `docs/API与功能说明.md`.

## How do I build from source?

Use SwiftPM for fast development builds:

```bash
swift build
```

For an app bundle:

```bash
./scripts/build-app.sh
open dist/PromptPanel.app
```

## Why does `swift test` sometimes only build tests locally?

On machines with only Command Line Tools, `xctest` may be unavailable. In that case `swift test` can prove compilation but cannot be counted as full XCTest execution. The release gate exposes this explicitly; use `./scripts/release-readiness.sh --allow-build-only-tests` only when accepting that downgrade.

## How should UI changes be made?

Update `frontend-draft/` first because it is the visual source of truth. Then align the SwiftUI/AppKit implementation and include the corresponding validation in the PR.

## Where is the roadmap?

The public roadmap and contribution scope are in `docs/路线图与贡献指南.md`. Import/export, repeat last entry, search/tag improvements, and compatibility samples are in scope; cloud sync, teams, and workflow orchestration are not.
