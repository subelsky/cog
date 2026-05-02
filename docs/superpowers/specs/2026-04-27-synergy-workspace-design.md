# Synergy Workspace — Design

**Date:** 2026-04-27
**Status:** Draft, awaiting user review
**Replaces:** ad-hoc layout under `~/Documents/4-Synergy/`

## Problem

The current personal-AI environment is awkwardly placed:

- The cog repo lives at `~/Documents/4-Synergy/`, an unnatural fit inside a PARA-organized Documents folder.
- Claude sessions started in `~/Documents/4-Synergy/` are blind to actual project work in `~/Documents/0-Projects/` and `~/Documents/1-Areas/`.
- Sessions started in `~/Documents/` lose access to cog and ember.
- The `4-Synergy` name is a sort-order hack, not a meaningful category.
- Tool surface is implicit: bash workarounds get re-approved per session because there's no curated CLI directory.

## Goals

- One coherent home for the AI workspace, separate from user files.
- Daily-driver Claude session has full access to cog (memory), ember (knowledge base read), Documents (PARA), MCP servers, and a curated set of host CLIs.
- Software development always runs inside supercontainers under `--dangerously-skip-permissions`, with read-write cog and read-only ember.
- Ember integration runs inside the existing clean room sandbox.
- No git repo at `~/Documents/` root; Documents stays a pure user filesystem.
- Custom CLIs are deliberately curated — adding a tool to `~/Synergy/bin/` is the only step needed to grant Claude access.

## Non-goals

- Reorganizing PARA folders.
- Refactoring cog skills beyond a path audit.
- Building a `synergy` launcher CLI (existing per-session launchers are kept).
- Restructuring `~/super_containers/` beyond updating two mount paths.
- Moving the `tools/` source repo (stays inside super_containers).

## Architecture

Three Claude session types, each with a distinct role:

| Session | Cwd | Permission mode | Cog | Ember | MCP | Notes |
|---|---|---|---|---|---|---|
| Daily driver | `~/Synergy/` | normal (prompts) | RW | RO (curated pages only) | yes | Orchestrator / conscience. Light edits in Documents. |
| Personal supercontainer | container `/workspace/` | `--dangerously-skip-permissions` | RW (mount) | RO (curated pages only, mount) | none | Software development for personal projects. |
| Work supercontainer | container `/workspace/` | `--dangerously-skip-permissions` | RW (mount) | RO (curated pages only, mount) | none | Software development for TrayVerify. |
| Clean room | container `/workspace/` | `--dangerously-skip-permissions` | none | RW (`esper/` only) | none | Ember ingestion (`/integrate`). |

Sessions don't talk to each other. Coordination is implicit via shared cog: any session writing observations or dev-log entries lands in the same `~/Synergy/memory/` files that the next host-driver session reads on startup.

## Directory Layout

```
~/
├── Synergy/                          # AI workspace — git repo (renamed from 4-Synergy)
│   ├── CLAUDE.md
│   ├── .claude/
│   │   ├── settings.json             # cwd=~/Synergy + scoped additionalDirectories
│   │   ├── settings.local.json       # gitignored personal overrides
│   │   ├── commands/                 # cog skills
│   │   └── agents/
│   ├── .mcp.json                     # apple-events, things, etc.
│   ├── memory/                       # cog — own git repo, gitignored from Synergy
│   ├── esper/                        # ember — own git repo, gitignored from Synergy
│   ├── clean_room/                   # ember integration sandbox
│   ├── bin/                          # curated CLI symlinks (gitignored except .gitkeep)
│   ├── docs/                         # cog reference docs, design specs
│   └── README.md
│
├── Documents/                        # Pure PARA — zero Claude artifacts
│   ├── 0-Projects/
│   ├── 1-Areas/
│   ├── 2-Resources/
│   ├── 3-Archive/
│   ├── Inbox/
│   └── (loose user files)
│
├── super_containers/                 # Unchanged. Mounts cog/ember from ~/Synergy/.
│   ├── personal/
│   └── work/
│
└── .synergy/
    └── env                           # exports SYNERGY_HOME, prepends bin to PATH
```

### Path conventions

- Cog skills continue to use cwd-relative paths (`memory/...`). Since cwd is now `~/Synergy/`, these resolve correctly without modification.
- Containers see cog at `/cog/` (rw) and ember at `/ember/` (ro), via mounts.
- Clean room continues to use the existing `SYNERGY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"` resolution. Since `clean_room/` moves with everything else, the script computes `SYNERGY_DIR=~/Synergy` automatically.

## Permissions, Mounts, and Allowlist

### Daily driver — `~/Synergy/.claude/settings.json`

```json
{
  "permissions": {
    "additionalDirectories": [
      "~/Documents/0-Projects",
      "~/Documents/1-Areas",
      "~/Documents/2-Resources",
      "~/Documents/3-Archive"
    ],
    "allow": [
      "Bash(~/Synergy/bin/*:*)",
      "Read(~/Documents/0-Projects/**)",
      "Read(~/Documents/1-Areas/**)",
      "Read(~/Documents/2-Resources/**)",
      "Read(~/Documents/3-Archive/**)",
      "Edit(~/Documents/0-Projects/**)",
      "Edit(~/Documents/1-Areas/**)",
      "Edit(~/Documents/2-Resources/**)",
      "Edit(~/Documents/3-Archive/**)",
      "Read(~/Synergy/memory/**)",
      "Edit(~/Synergy/memory/**)",
      "Read(~/Synergy/esper/index.md)",
      "Read(~/Synergy/esper/log.md)",
      "Read(~/Synergy/esper/pages/**)"
    ],
    "deny": [
      "Read(~/Synergy/esper/raw/**)",
      "Read(~/Synergy/esper/_staging/**)",
      "Edit(~/Synergy/esper/**)"
    ]
  }
}
```

Notes:
- Scoping `additionalDirectories` to the four named PARA folders excludes `~/Documents/Inbox/` and loose Documents-root files from host Claude's view by design.
- `Bash(~/Synergy/bin/*:*)` is a wildcard allowlist — every symlink in `bin/` is auto-approved. Adding a tool to `bin/` is the deliberate gate.
- Deny rules block all ember writes and all reads of raw / staging storage. Clean room is the only ember writer.

### Supercontainers (personal + work)

Updates needed in `~/super_containers/{personal,work}/` launcher config:

- Mount `~/Synergy/memory/` rw → container `/cog/`
- Mount `~/Synergy/esper/pages/`, `esper/index.md`, `esper/log.md` ro → container `/ember/` (only the curated knowledge surface; raw/_staging are not mounted)
- Inject env vars into the container: `COG=/cog`, `EMBER=/ember`
- Permission mode unchanged: `--dangerously-skip-permissions`
- Both supercontainers get full cog scope (no work/personal namespace partition).

### Clean room

No structural changes. Path resolution updates implicitly because the directory moved. Verification step in Phase 5.

## Migration Plan

Six phases. Each independently verifiable; rollback is `mv ~/Synergy ~/Documents/4-Synergy` plus reverting super_containers config.

### Phase 0 — Pre-flight

- Commit and push outstanding work in `4-Synergy/` (modified `clean_room/entrypoint.sh`, `clean_room/start.sh`, `.claude/commands/reflect.md`, `.claude/settings.local.json`).
- Push `memory/` and `esper/` to their own remotes.
- Confirm no live super_containers or clean_room sessions running.
- Optional: `tar -czf ~/synergy-pre-migration.tar.gz ~/Documents/4-Synergy` for a one-shot escape hatch.

### Phase 1 — The move

- `mv ~/Documents/4-Synergy ~/Synergy`

### Phase 2 — Host shell environment

- Create `~/.synergy/` directory and `~/.synergy/env` containing:
  ```sh
  export SYNERGY_HOME="$HOME/Synergy"
  export PATH="$SYNERGY_HOME/bin:$PATH"
  ```
- Add `[ -f ~/.synergy/env ] && source ~/.synergy/env` to `~/.zshrc`.
- `mkdir ~/Synergy/bin && touch ~/Synergy/bin/.gitkeep`
- Update `~/Synergy/.gitignore` to add `bin/*` and `!bin/.gitkeep`.

### Phase 3 — Path audit and Claude config

- `grep -rn '4-Synergy' ~/Synergy/` and `grep -rn 'Documents/4-Synergy' ~/Synergy/`. Update any matches found in:
  - `CLAUDE.md`
  - `.claude/commands/*.md`
  - `.claude/settings.json`
  - `.claude/settings.local.json`
  - `clean_room/start.sh`, `entrypoint.sh`, `Containerfile`
  - `docs/`
- Replace `~/Documents/4-Synergy` references with `~/Synergy` (or `$SYNERGY_HOME`).
- Replace bare `4-Synergy` references with `Synergy` where they refer to the directory name.
- Update `~/Synergy/.claude/settings.json` to the permissions block specified above.

### Phase 4 — Update super_containers

- In `~/super_containers/personal/` launcher: change cog mount source from `~/Documents/4-Synergy/memory` to `~/Synergy/memory`. Same for ember (from `~/Documents/4-Synergy/esper/pages` etc. to `~/Synergy/esper/pages` etc.).
- Same updates in `~/super_containers/work/`.
- Verify env-var injection (`COG`, `EMBER`) is present; add if missing.

### Phase 5 — Verify clean_room

- `~/Synergy/clean_room/start.sh shell`
- Inside the container, confirm `/workspace` is mounted from `~/Synergy/` and the existing `/sources/` mounts resolve.
- Exit cleanly without running `/integrate`.

### Phase 6 — Smoke tests

In order:

1. **Daily driver loads cleanly.** `cd ~/Synergy && claude`. Confirm `hot-memory.md` and `cog-meta/patterns.md` load. Activate `/personal`. Confirm MCP servers (apple-events, things) connect.
2. **Documents access works.** From host Claude, read a file under `~/Documents/0-Projects/` to confirm `additionalDirectories` is functioning.
3. **Ember deny rule fires.** Attempt to read a file under `~/Synergy/esper/raw/`. Confirm it is denied.
4. **Bin allowlist works.** Symlink a trivial CLI (e.g., `ln -s /usr/bin/date ~/Synergy/bin/today`), invoke from host Claude, confirm no permission prompt.
5. **Personal supercontainer cog write-back.** Launch personal supercontainer Claude. Append a test entry to `memory/personal/observations.md`. Exit. From host, read the file. Confirm the write landed.
6. **Clean room ingest dry run.** Launch `~/Synergy/clean_room/start.sh`. Run a `/integrate` dry-run (or no-op equivalent) to confirm source mounts and `esper/` overlay still work end-to-end.
7. **Work supercontainer cog write-back.** Same as #5 but in `memory/work/trayverify/`.

### Rollback

At any point during phases 1-6:

- `mv ~/Synergy ~/Documents/4-Synergy`
- Revert super_containers config changes (`git checkout` in those repos).
- Remove the `source ~/.synergy/env` line from `~/.zshrc` if you want to fully undo.
- The `~/.synergy/env` file is harmless when its target doesn't exist.

## Open Questions

None remaining at design time. Path audit (Phase 3) may surface specific edits not anticipated here; spec assumes those are mechanical replacements rather than structural changes.

## Risks

- **Hardcoded path references.** Cog skills and pipeline tooling may have references to `4-Synergy` not caught by the grep audit (e.g., paths constructed from variables). Mitigated by Phase 6 smoke tests; remaining cases will surface during normal use.
- **Spotlight reindex.** macOS will reindex `~/Synergy/` at the new location. Cosmetic; no functional impact.
- **External references.** Any cron jobs, scheduled agents, shortcuts, or `~/.claude/` user-level config that hardcodes `4-Synergy` paths will need updating. Out of scope for this spec; user identifies and updates as encountered.

## Success Criteria

- `cd ~/Synergy && claude` starts a daily-driver session with cog, ember (read-only via curated pages), all four PARA folders, and MCP servers all functional.
- All Phase 6 smoke tests pass.
- `~/Documents/` contains no Claude artifacts (no `CLAUDE.md`, no `.claude/`, no `4-Synergy/`).
- Adding a CLI to `~/Synergy/bin/` requires no settings.json change to be auto-approved by host Claude.
- Existing super_containers and clean_room workflows continue to work end-to-end.
