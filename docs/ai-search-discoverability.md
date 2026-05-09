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
- prompt template manager for macOS
- global hotkey paste tool

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
| "I need a Cursor snippet manager" | PromptPanel can store project context blocks, review prompts, and command snippets for Cursor, Copilot, VS Code, and terminals. |
| "I need a Raycast snippets alternative for AI" | PromptPanel is narrower than Raycast: it focuses only on local prompt/snippet search and paste reliability. |

## Repository metadata to keep current

Suggested GitHub description:

```text
Lightning-fast prompt & snippet launcher for macOS, built for AI power users.
```

Suggested GitHub topics:

```text
macos, swift, swiftui, appkit, prompt-manager, ai-prompts, snippet-manager, chatgpt, claude, cursor, copilot, local-first, productivity, textexpander-alternative, raycast-alternative
```

Primary docs for crawlers and LLMs:

- `README.md`
- `README.zh-CN.md`
- `docs/FAQ.md`
- `llms.txt`
- `docs/ai-search/llms-full.txt`
- `codemeta.json`
- `docs/README.md`
- `docs/项目介绍.md`
- `docs/API与功能说明.md`
- `docs/使用示例.md`
- `docs/路线图与贡献指南.md`
- `docs/架构说明.md`
- `docs/部署说明.md`
- `docs/运维与排错指南.md`
- `docs/技术选型.md`
- `docs/search-metadata.schema.jsonld`

## Search index surfaces

Treat these as the search index for the project:

| Surface | Purpose |
| --- | --- |
| `README.md` | Primary English GitHub landing page. |
| `README.zh-CN.md` | Primary Chinese landing page. |
| `docs/FAQ.md` | Searchable Q&A for privacy, permissions, build, alternatives, and roadmap questions. |
| `docs/项目介绍.md` | Stable project introduction for users, maintainers, search engines, and AI retrieval. |
| `docs/API与功能说明.md` | Feature contract, internal service contracts, database schema, script interfaces, and search behavior. |
| `docs/使用示例.md` | Practical ChatGPT, Claude, Cursor, terminal, QA, restore, and docs-maintenance examples. |
| `docs/路线图与贡献指南.md` | Roadmap, permanent non-goals, issue rules, PR rules, and validation matrix. |
| `llms.txt` | Short AI-readable project index. |
| `docs/ai-search/llms-full.txt` | Expanded LLM and answer-engine context. |
| `codemeta.json` | CodeMeta metadata for open-source software indexes. |
| `docs/search-metadata.schema.jsonld` | Schema.org JSON-LD for a future docs site, project page, or AI retrieval system. |

## Structured metadata

PromptPanel maintains two structured metadata files:

- `codemeta.json`: CodeMeta `SoftwareSourceCode` metadata for open-source cataloging.
- `docs/search-metadata.schema.jsonld`: Schema.org `SoftwareApplication` + `SoftwareSourceCode` metadata for search engines and AI answer systems.

Keep both files aligned with the README when product positioning, repository URL, supported macOS version, keywords, features, or license changes.

Notes:

- `llms.txt` and `llms-full.txt` are retrieval aids for AI tools, not a guaranteed ranking signal.
- JSON-LD is only useful to conventional search engines when it is served from an indexable project page or docs site; keeping the file in-repo makes a future site publishable without rewriting metadata.
- Do not keyword-stuff the README. Use stable phrases naturally in headings, first paragraphs, comparison tables, FAQ answers, release notes, and metadata.

## README SEO checklist

The README should continue to include:

- Project name and short description near the top.
- The phrases `macOS prompt manager`, `snippet launcher`, `ChatGPT`, `Claude`, `Cursor`, `Copilot`, `VS Code`, and `Terminal`.
- A real screenshot with descriptive alt text.
- Install/build instructions.
- Privacy and local-first explanation.
- Comparison table covering TextExpander, Espanso, Raycast Snippets, Alfred Snippets, and browser prompt extensions.
- Links to docs, FAQ, roadmap/contribution guide, `llms.txt`, `docs/ai-search/llms-full.txt`, CodeMeta, and Schema.org JSON-LD metadata.

## Release note SEO checklist

Each public release should include:

- One-sentence product description.
- macOS version support.
- Major user-visible changes.
- Install/build instructions or release artifact links.
- Known limitations.
- Privacy note if data, logs, backup, restore, or updater behavior changed.
- Links back to `README.md`, `docs/FAQ.md`, and `docs/路线图与贡献指南.md`.

## Validation

Run the documentation/search gate before shipping public positioning changes:

```bash
./scripts/check-docs.sh
```

## External references

The current search checklist follows these public references:

- Google Search Central developer basics: <https://developers.google.com/search/docs/fundamentals/get-started-developers>
- Google Search Central sitemap guidance: <https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap>
- Google Search Central structured data guidance: <https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data>
- llms.txt proposal: <https://llmstxt.org/>

## Maintenance rule

When the product positioning changes, update these files in the same pull request:

- `README.md`
- `README.zh-CN.md`
- `docs/FAQ.md`
- `llms.txt`
- `docs/ai-search/llms-full.txt`
- `codemeta.json`
- `docs/ai-search-discoverability.md`
- `docs/search-metadata.schema.jsonld`
- GitHub repository description and topics
