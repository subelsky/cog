# Cog Upstream Re-Baseline — Design

**Date:** 2026-08-14
**Status:** Draft, awaiting user review
**Repos:** Synergy (skills, `CLAUDE.md`, docs) and `memory/` (its own repo)
**Upstream:** [`marciopuga/cog`](https://github.com/marciopuga/cog) @ `86de1eb`
**Implementation order:** third of three (esper-lint → container split → this)

## Problem

Synergy forked cog and has since diverged by roughly 20 upstream commits. The drift is
architectural, not cosmetic, and it costs tokens on every single turn.

### Upstream restructured where conventions live

Upstream moved the entire memory convention set out of `CLAUDE.md` and into a `/cog` skill.
`CLAUDE.md` went to 125 lines; `cog.md` holds ~480. Synergy's `CLAUDE.md` is 288 lines carrying
every convention inline.

`CLAUDE.md` loads on **every turn of every session**. A skill loads once, on demand. Synergy is
currently paying full price for the memory spec — glacier archival rules, file-edit-pattern
tables, retrieval protocols — in conversations that never touch memory at all.

The same pattern applies one level down: upstream's domain skills became 23-line activation shims
that defer all behavior to the cog skill. Synergy's are 43–60 lines each across 7 domain skills,
re-stating routing logic that now has a canonical home.

### Features Synergy does not have

| Upstream feature | Synergy today |
|---|---|
| `COG_HOME` memory path resolution | hardcoded relative paths |
| Temporal validity markers `<!-- until:D grace:N -->` / `<!-- from:D -->` | prose rule: "mark old value as superseded with date" |
| `cog-meta/run-log.md`, `- YYYY-MM-DD /skill: outcome`, scopes "since last run" | reflect-only `reflect-cursor.md`, no other skill has scoping |
| Consolidation condition pipeline — 3 gates, `<!-- promoted: -->` audit trail | "distill 3+ on same theme" |
| Spike detection (≥5 entries in <7 days = heating topic) | absent |
| `/reflect` minimum-data checks | absent — will produce weak patterns from thin data |
| Threads at `{domain}/threads/{slug}.md` | threads live loose in the domain dir |
| `cog-meta/action-items.md` | absent |
| Generated per-domain `INDEX.md` with L0 table | `INDEX.md` files exist but are not maintained |
| Weekly `housekeeping → reflect` in one session, monthly `evolve` | weekly-or-nightly per skill |

### Local conformance gaps, independent of upstream

- **12 memory files fail the L0-on-line-1 convention** — but only 4 genuinely lack an L0
  (`link-index.md`, `glacier/index.md`, `foresight-nudge.md`, `briefing-bridge.md`). The other 8
  (all 7 domain `INDEX.md` files plus `reflect-cursor.md`) have a correct L0 on line **2**, under
  the title, because housekeeping's INDEX generator emits title-then-L0. Those get promoted, not
  rewritten — and the generator itself must be fixed, or the next housekeeping run reverts them.
- **The pattern-routing rule is unused but retained.** `CLAUDE.md` rule 7 specifies core vs.
  satellite pattern files. No satellite file exists — only `cog-meta/patterns.md`. Upstream's
  `cog.md` ships the same core/satellite split, so it survives the re-baseline for free rather
  than being dropped as originally planned.
- **`docs/cog/*.md` are stale.** Six local copies of upstream docs that upstream has since moved
  to <https://lab.puga.com.br/cog/>.

### A finding worth stating plainly

Total observations across all domains: **25** (personal 9, cog-meta self-observations 10,
trayverify 4, storyfield 2, four domains at 0). No thread files exist. No satellite pattern files
exist.

The memory system is nearly empty relative to the machinery being maintained around it. Adopting
the consolidation gates is still correct — they encode good judgment and prevent noise — but they
will rarely fire at this data volume. The honest framing is that this re-baseline buys a cleaner,
cheaper foundation, not immediate new insight. The thing most likely to make the system useful is
capturing more observations, which no amount of pipeline refinement substitutes for.

## Goals

- `CLAUDE.md` back to roughly upstream size, with Synergy deltas explicit rather than woven in.
- Conventions in a `/cog` skill, loaded on demand.
- Domain skills as thin shims.
- Adopt upstream's substantive features, all listed above.
- Nothing Synergy-specific is lost silently — every drop is enumerated for veto.

## Non-goals

- Re-deriving upstream's conventions. Where upstream and Synergy disagree on a convention with no
  Synergy-specific reason, upstream wins.
- Changing Esper. `/esper` and `/integrate` are Synergy inventions with no upstream counterpart.
- Backfilling memory content.
- Tracking upstream continuously. This is a one-time catch-up; a `docs/cog/UPSTREAM.md` note
  records the synced commit so the next catch-up has a diff base.

## Design

### Layering

Upstream's `CLAUDE.md` and `cog.md` become the base. Synergy deltas re-apply on top as clearly
marked additions:

| Delta | Lands in |
|---|---|
| Esper directory map, `esper/` file-edit-pattern rows | `cog.md` (Synergy section) |
| `/esper`, `/integrate` skill table rows | `CLAUDE.md` |
| The 7 domain skills + their routing table | `CLAUDE.md` |
| Session-transcript JSONL format notes | `/reflect` skill |
| Raw-data container boundary, `SYNERGY_RAW` | `CLAUDE.md` (from spec 2) |
| Persona lines specific to the user | `CLAUDE.md` |

Target: `CLAUDE.md` ~140 lines, `cog.md` ~500, 7 domain shims at ~25 each.

### Deviation from upstream: memory path resolution

Upstream resolves memory as `$COG_HOME/memory/`, falling back to `~/cog/memory/`. Synergy sessions
always start at the repo root, and memory lives at `<repo>/memory/`.

Adopted form: **`$COG_HOME/memory/` if set, otherwise `./memory/` relative to the project root.**

One word different from upstream, works in both host and container with zero configuration, and
leaves `COG_HOME` functional if memory should later be reachable from another workspace. The
`~/cog` fallback is wrong for Synergy and would silently resolve to a nonexistent directory.

### Features adopted

**Temporal validity markers.** `<!-- until:YYYY-MM-DD grace:N -->` on time-bounded facts,
`<!-- from:YYYY-MM-DD -->` on stable-since facts. `/housekeeping` sweeps expired `until:` markers;
`/reflect` flags `from:` markers older than 6 months for review. This replaces the current prose
rule, which produces no machine-checkable state. Existing memory files are not retrofitted —
markers get added as facts are next touched.

**`cog-meta/run-log.md`.** Append-only, `- YYYY-MM-DD /skill: outcome`. Every pipeline skill
appends on completion and reads it to scope "since last run" (default: last 7 days when there is
no entry). Seeded with a single dated line at creation so the first run does not attempt to mine
the full history.

This supersedes `reflect-cursor.md` for *scoping*, but not for *transcript ingestion* —
`reflect-cursor.md` tracks per-project-directory JSONL positions, which the run log does not model.
Both stay; the spec documents the split so they do not drift into overlap.

**Consolidation condition pipeline.** Three gates in `/reflect`:
1. Cluster — ≥3 entries, same primary tag, ≥7-day span, ≥3 distinct dates, tag is specific
   (rejects `work`, `home`, `general`, `misc`).
2. Coverage — check existing patterns; skip if covered, REPLACE if the new insight subsumes.
3. Synthesis — one actionable line, style-matched, with a `<!-- promoted:YYYY-MM-DD theme:tag -->`
   audit trail.

Plus spike detection: ≥5 entries in <7 days marks a heating topic — a thread candidate, not
pattern-ready.

**Minimum-data checks in `/reflect`.** Refuses to run below 5 total observations; flags when
nothing changed in 7 days; declines to consolidate when `patterns.md` is empty and observations
are under 10. Directly relevant at 25 observations.

**Threads move to `{domain}/threads/{slug}.md`.** No files to migrate — none exist. This creates
`threads/.gitkeep` in each domain and updates the thread-raising instructions. Upstream also
changes the semantics: `/reflect` *suggests* candidates and creates a thread only on user
approval.

**`cog-meta/action-items.md`.** For meta-level tasks about the system itself, which currently have
nowhere to live except `improvements.md`.

**Per-domain `INDEX.md` as generated L0 tables.** `/housekeeping` regenerates them. This also
closes the L0 gap: all 12 files missing an L0 header get one, generated files included.

**Pipeline cadence.** Weekly `housekeeping → reflect` in a single session so reflect sees cleaned
state; monthly `evolve`. Upstream explicitly calls running everything nightly "theatrical." The
`CLAUDE.md` pipeline table and `docs/synergy-user-guide.md` both change.

### Explicitly dropped — review these

Each of these exists in Synergy today and does not survive. Veto individually.

| Dropped | Why |
|---|---|
| `docs/cog/*.md` (6 files) | Stale copies of docs upstream moved to a website. Replaced by a URL in `docs/cog/UPSTREAM.md`. |
| `/setup` | Renamed `/cog` upstream. Kept as a one-line alias file pointing at `/cog` so muscle memory does not break. |
| `.claude/commands/_templates/domain.md` | Rewritten, not dropped — regenerated in the thin-shim form. |
| Long-form "Raising a thread" prose in `CLAUDE.md` | Moves to `cog.md`, compressed to upstream's form. |
| Detailed glacier archival tables in `CLAUDE.md` | Moves to `cog.md`. Content preserved, location changes. |
| Detailed L0/L1/L2 retrieval prose in `CLAUDE.md` | Moves to `cog.md`, compressed. |
| Session-transcript JSONL format notes in `CLAUDE.md` | Moves to `/reflect`, the only consumer. |

Nothing on this list is deleted outright except the stale docs. The rest relocates.

### `memory/` repo migration

Committed separately from the Synergy changes.

1. `mkdir memory/{domain}/threads/` + `.gitkeep` for the 7 content domains (`cog-meta` is `type: system` and gets none).
2. Create `cog-meta/run-log.md` with an L0 header and one seed line dated at implementation.
3. Create `cog-meta/action-items.md` with an L0 header.
4. Add L0 headers to the 12 files missing them.
5. Update `domains.yml` — regenerate its header comment (`generated by /setup` → `/cog`) and add
   `threads` to each domain's `files` list.

`reflect-cursor.md`'s stale path is fixed in spec 2, step 4, not here.

## Migration

1. Vendor upstream `cog.md` into `.claude/commands/`, apply the `./memory/` path deviation.
2. Add the Esper section to `cog.md`.
3. Rewrite `CLAUDE.md` from upstream's base plus the delta table above.
4. Rewrite the 7 domain skills as shims; regenerate `_templates/domain.md`.
5. Update the 9 skills Synergy shares with upstream (`reflect`, `housekeeping`, `evolve`,
   `foresight`, `scenario`, `history`, `explainer`, `humanizer`, `commit`) from upstream,
   re-applying any Synergy-specific content each carries.
6. `memory/` repo migration (5 steps above).
7. Delete `docs/cog/*.md`, write `docs/cog/UPSTREAM.md` recording commit `86de1eb`.
8. Update `docs/synergy-user-guide.md` — skill table, cadence, `/setup` → `/cog`.
9. Add `/setup` alias.

Steps 1–5 are the reviewable core; 6–9 are mechanical.

## Verification

- `wc -l CLAUDE.md` ≤ 160.
- Every skill named in the `CLAUDE.md` routing table has a file in `.claude/commands/`, and every
  file is in the table.
- `grep -rn "COG_HOME\|memory/" .claude/commands/` — no skill references `~/cog/memory`.
- `grep -rn "clean_room\|/setup\|docs/cog/" .claude/commands/ CLAUDE.md docs/` — no dead
  references.
- Every `.md` under `memory/` has `<!-- L0:` on line 1.
- Smoke test in a fresh session: `/personal` activates and loads domain memory; `/esper` runs a
  query; `/reflect` runs and correctly declines or scopes based on the run log.

## Risks

- **Silent loss of a Synergy convention.** The dropped-items table is the mitigation, and it is
  the main thing to review. A full diff of the old `CLAUDE.md` against the new `CLAUDE.md` +
  `cog.md` pair is part of the implementation plan.
- **Upstream's conventions may not fit 7 domains.** Upstream ships one domain (`personal`).
  Synergy runs 7, most nearly empty. The thin-shim pattern is untested at that width; if the
  shims prove too thin to route correctly, the fix is adding trigger specificity back to
  individual shims, not abandoning the pattern.
- **`cog.md` becomes the new fat file.** It is ~500 lines, loaded whenever a domain skill
  activates — which is most memory sessions. The saving is real but smaller than the raw line
  counts imply. Worth measuring after the fact rather than assuming.
- **Ordering dependency on spec 2.** Both specs edit `CLAUDE.md`. Spec 2 lands first; this one
  rewrites the file wholesale and must carry spec 2's container-boundary content forward.
- **This is a large diff against a nearly-empty memory store.** If the review cost exceeds
  appetite, the honest fallback is the cherry-pick option from the original discussion: take
  temporal markers, the run log, and the consolidation gates, and leave `CLAUDE.md` fat.

## Success criteria

- `CLAUDE.md` ≤ 160 lines with all 7 domains, Esper, and the container boundary intact.
- `/cog` exists; `/setup` aliases to it.
- All 7 domain skills are shims of ~25 lines.
- All adopted features are present and referenced by the skill that owns them.
- Every memory file has an L0 header.
- No dead references to `docs/cog/*`, `clean_room`, or `~/cog/memory`.
- A fresh session routes to a domain and answers a memory question correctly.
