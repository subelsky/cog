# Upstream Cog — Sync Record

Synergy is a fork of [marciopuga/cog](https://github.com/marciopuga/cog), a plain-text memory
system for AI agents.

**Docs:** <https://lab.puga.com.br/cog/> — the canonical reference. This directory previously held
six local copies of those docs (`architecture.md`, `memory.md`, `pipeline.md`, and four
`pipeline/*.md` files). They had gone stale against both upstream and Synergy's own conventions,
so they were deleted rather than refreshed. Read the website, or read `.claude/commands/cog.md`,
which is the vendored skill and the operative source of truth here.

## Sync history

| Date | Upstream commit | Notes |
|------|-----------------|-------|
| 2026-08-14 | `86de1eb` | Full re-baseline. See `docs/superpowers/specs/2026-08-14-cog-upstream-rebaseline-design.md`. |

To diff against upstream for the next catch-up:

```sh
git clone https://github.com/marciopuga/cog /tmp/cog-upstream
cd /tmp/cog-upstream && git log --oneline 86de1eb..HEAD
```

## Synergy's deviations from upstream

Keep this list short. Every entry is friction at the next sync.

### 1. Memory path fallback

Upstream resolves memory as `$COG_HOME/memory/`, falling back to `~/cog/memory/`. Synergy falls
back to **`./memory/`**, relative to the project root.

*Why:* Synergy sessions always start at the repo root, and memory lives at `<repo>/memory/`.
Upstream's fallback points at a directory that does not exist here. The project-relative form
resolves correctly on the macOS host *and* inside a container with no environment configuration —
which is what makes the host/container split work. `COG_HOME` still takes precedence if set.

### 2. Esper

`esper/` — a compiled knowledge base with its own ingestion pipeline (`/integrate`) and query
skill (`/esper`) — has no upstream counterpart. It is documented inside `cog.md` under a clearly
marked "Esper — The Knowledge Base (Synergy only)" heading so the boundary stays visible at the
next sync. Spec: `docs/superpowers/specs/2026-04-11-esper-design.md`.

### 3. Environment split

Synergy runs across a macOS host and a raw-data container, with `/integrate` gated on
`SYNERGY_RAW=1`. Upstream assumes one machine. Documented in `CLAUDE.md` and
`docs/superpowers/specs/2026-08-14-synergy-container-split-design.md`.

### 4. Seven domains, not one

Upstream ships `personal`. Synergy runs seven content domains plus `cog-meta`. No convention
change — just more instances of the same shim pattern.

### 5. `reflect-cursor.md`

Synergy keeps `memory/cog-meta/reflect-cursor.md` alongside upstream's `run-log.md`. They do
different jobs: the run log scopes *which memory files to re-read*; the cursor tracks *positions
in Claude Code session transcripts* per project directory. Upstream has no transcript-mining step,
so it needs no cursor.
