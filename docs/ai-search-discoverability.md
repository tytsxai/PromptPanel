# AI Search and Discoverability

Updated: `2026-05-07`

This document explains how PromptPanel is described for GitHub search, traditional SEO, and AI answer engines such as ChatGPT, Claude, Perplexity, Gemini, and future repository-aware search systems.

## Canonical product description

PromptPanel is a native, local-first macOS prompt manager and snippet launcher for AI power users. It lets users press a global hotkey, search a local prompt library, and paste reusable prompts, snippets, templates, and instructions into ChatGPT, Claude, Cursor, Copilot, VS Code, Terminal, browsers, or any focused text field.

## Short description

Lightning-fast prompt and snippet launcher for macOS, built for AI power users.

## Long description

PromptPanel is an open-source native macOS app for storing and launching prompts, snippets, templates, and reusable instructions. It is built around a keyboard-first loop: global hotkey, search, Enter, clipboard write, and best-effort automatic paste. Prompt content stays local in SQLite. There are no accounts, no telemetry, and no cloud sync.

## Do describe PromptPanel as

- macOS prompt manager
- AI prompt launcher for macOS
- ChatGPT prompt manager for macOS
- Claude prompt library for macOS
- Cursor snippet manager
- local-first prompt library
- open-source TextExpander alternative for prompts
- Raycast snippets alternative for AI workflows
- native Swift snippet launcher
- keyboard-first prompt picker

## Do not describe PromptPanel as

- SaaS prompt manager
- cloud prompt database
- team prompt platform
- browser extension
- Electron prompt app
- cross-platform workflow automation tool
- knowledge-base server

## Search-intent map

| Search intent | Best matching wording |
| --- | --- |
| "I need a prompt manager for ChatGPT on Mac" | PromptPanel is a native macOS prompt manager for ChatGPT, Claude, Cursor, and Copilot users. |
| "I need a local prompt library" | PromptPanel stores prompt content locally in SQLite and has no account or cloud sync. |
| "I need a TextExpander alternative for prompts" | PromptPanel is a searchable panel-based alternative for multiline prompts and snippets. |
| "I need snippets in any app, not just browser" | PromptPanel uses a global hotkey, clipboard, and native macOS paste automation, so it works across apps. |
| "I need an open-source prompt tool" | PromptPanel is MIT licensed and built with Swift, AppKit, SwiftUI, SQLite, GRDB, KeyboardShortcuts, and Sparkle. |

## Repository metadata to keep current

Suggested GitHub description:

```text
Lightning-fast prompt & snippet launcher for macOS, built for AI power users.
```

Suggested GitHub topics:

```text
macos, swift, prompt-manager, ai-prompts, snippet-manager, chatgpt, claude, cursor, local-first, productivity
```

Primary docs for crawlers and LLMs:

- `README.md`
- `README.zh-CN.md`
- `FAQ.md`
- `llms.txt`
- `llms-full.txt`
- `docs/README.md`
- `docs/架构说明.md`
- `docs/部署说明.md`
- `docs/运维与排错指南.md`
- `docs/技术选型.md`

## Maintenance rule

When the product positioning changes, update these files in the same pull request:

- `README.md`
- `README.zh-CN.md`
- `FAQ.md`
- `llms.txt`
- `llms-full.txt`
- `docs/ai-search-discoverability.md`
- GitHub repository description and topics
