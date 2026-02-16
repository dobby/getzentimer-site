# CLAUDE.md

## Project Overview
GetZenTimer website is a static marketing/support site (`index.html`, `privacy.html`, `support.html`) with assets in `assets/` and GitHub Pages deployment via Actions.

## Repository Boundaries
- This repository is the website for the ZenTimer iOS app.
- iOS app implementation lives in `~/projects/ZenTimer` (absolute path: `/Users/eli/projects/ZenTimer`).
- Do not implement iOS app code changes in this website repo.

## Shared Docs
- App docs directory: `~/projects/ZenTimer/docs` (absolute path: `/Users/eli/projects/ZenTimer/docs`)
- App note references: `~/projects/ZenTimer/AGENTS.md` (absolute path: `/Users/eli/projects/ZenTimer/AGENTS.md`)
- App architecture reference: `~/projects/ZenTimer/ARCHITECTURE.md` (absolute path: `/Users/eli/projects/ZenTimer/ARCHITECTURE.md`)

## General Guidelines
- Do not expand scope beyond what the user explicitly requests. If you think a broader solution would be better, briefly suggest it and wait for approval before proceeding.
- When creating an implementation plan, keep it concise and move to implementation quickly. If the user provides a detailed plan, start coding immediately rather than re-exploring or re-planning.

## Pitfalls (read before coding)
- **Metal export must compile source directly.** Use `device.makeLibrary(source:)`, not `makeDefaultLibrary()` in `tools/export_metal_backgrounds.swift`.
- **Smart App Banner is launch-gated.** Keep the `apple-itunes-app` meta tag placeholder aligned with the real numeric App Store ID before launch.

## Agent Notes

After completing work, save reusable knowledge in `docs/notes/`. Focus on **gotchas and constraints** — not changelogs.

**Note format** (required sections):
- `## Gotchas` — things that will break or surprise. Put these first.
- `## How it works` — architecture and key decisions, only what's needed to work in this area.
- `## Files` — key files involved (optional, only if non-obvious).

**Rules:**
- Update existing notes when new knowledge contradicts them
- `git add` new note files
- **Transparency:** When consulting a reference during a task, cite which notes you used in your summary or plan.
- **Cleanup:** When references exceed 10 items, or manually via the `.skills/agent-consolidate-notes` procedure, consolidate related notes and remove stale entries.

### References
- [website-notes](docs/notes/website-notes.md) — Read before: editing landing/support/privacy content, glass UI behavior, background export, launch links, or Pages deployment settings
- `~/projects/ZenTimer/docs` (absolute path: `/Users/eli/projects/ZenTimer/docs`) — Shared app docs from the main ZenTimer project
- `~/projects/ZenTimer/AGENTS.md` (absolute path: `/Users/eli/projects/ZenTimer/AGENTS.md`) — Main app agent guidance and note references
