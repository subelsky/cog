---
name: cog
description: >
  Plain-text persistent memory system. Conventions for L0 progressive loading,
  three-tier storage (hot/warm/glacier), single-source-of-truth, temporal validity,
  wiki-links, and the Esper knowledge base. Run /cog to bootstrap or reconfigure domains.
---

# Cog

A plain-text memory system that gives any AI agent persistent memory across sessions. Memory lives in a local folder as markdown files — observable, editable, git-trackable.

Vendored from [marciopuga/cog](https://github.com/marciopuga/cog) @ `86de1eb`. See `docs/cog/UPSTREAM.md` for the sync record and the one deviation Synergy carries.

## Memory Path

Resolved in this order:

1. `$COG_HOME/memory/` — if the `COG_HOME` environment variable is set
2. `./memory/` — relative to the Synergy project root (the default)

**Synergy deviation from upstream.** Upstream falls back to `~/cog/memory/`. Synergy sessions always start at the repo root and memory lives at `<repo>/memory/`, so the fallback is the project-relative path. This resolves correctly on the macOS host *and* inside a container without any environment configuration.

## Three Tiers

| Tier | Where | Loaded | Size limit | Edit mode |
|------|-------|--------|-----------|-----------|
| **Hot** | `memory/hot-memory.md` | Every conversation | <50 lines | Rewrite freely |
| **Warm** | Domain files (incl. domain `hot-memory.md`) | When domain activates | Per-file caps | File-specific |
| **Glacier** | `memory/glacier/` | On-demand (indexed) | Unlimited | Read-only (housekeeping archives) |

**Hot** = your desk. The root `memory/hot-memory.md` only — cross-domain current state, loaded every turn.
**Warm** = your filing cabinet. Domain files — *including each domain's own `hot-memory.md`* — loaded when the domain activates, not every turn. That's what keeps loading progressive.
**Glacier** = deep archive. Old observations, completed items. Indexed, searchable, never auto-loaded. Read-only, except when housekeeping appends archives and rebuilds `glacier/index.md`.

## L0 Headers (Progressive Context Loading)

Every memory file has a one-line L0 summary as the first line — a quick answer to "what would I find if I read this file?"

**Format:**
```
<!-- L0: summary here (max 80 chars) -->
```

### L0 → L1 → L2 Retrieval Protocol

- **L0** — Read the `<!-- L0: ... -->` header. Answer: "is this file relevant?"
- **L1** — Scan section headers (`## ...`, `### ...`). Answer: "which section is relevant?"
- **L2** — Read the full file or section.

**Decision rules:**
1. When uncertain which files are relevant, scan L0 headers across the domain directory first
2. If L0 confirms relevance but the file is >80 lines, scan section headers (L1) before full read
3. For files <80 lines or when you need full context, go directly to L2
4. Hot-memory files are always L2 — they're small by design

## Directory Structure

Domains are defined in `memory/domains.yml` — the single source of truth for all memory domains.

```
memory/
  domains.yml                      # Domain manifest
  hot-memory.md                    # Cross-domain (loaded every turn)
  link-index.md                    # Backlink index (auto-generated)
  cog-meta/                        # System self-knowledge
    self-observations.md           # What worked/didn't — append-only
    patterns.md                    # Distilled interaction rules — edit in place
    improvements.md                # Ideas, wishlists — edit in place
    action-items.md                # System tasks (evolve routes breaches here)
    run-log.md                     # Pipeline run log — append-only
    reflect-cursor.md              # Per-project transcript ingestion cursors
    scenario-calibration.md        # Scenario accuracy tracker (reflect updates)
    foresight-nudge.md             # Strategic nudge (foresight overwrites)
    briefing-bridge.md             # Housekeeping → foresight handoff
    scenarios/                     # Active decision scenarios
    INDEX.md                       # Per-domain L0 index (auto-generated)
  personal/                        # Default domain
    hot-memory.md
    observations.md
    action-items.md
    entities.md
    calendar.md
    health.md
    habits.md
    threads/                       # Synthesis files (created on promotion)
    INDEX.md                       # Per-domain L0 index (auto-generated)
  work/                            # Work and side-project domains
    <domain>/                      # Same structure, per domains.yml
  glacier/                         # Archived data by domain
    index.md                       # Glacier catalog (auto-generated)
```

## Memory Rules

1. **Read on start**: Always read `memory/hot-memory.md` and `memory/cog-meta/patterns.md`
2. **Write immediately**: Don't wait to save something worth remembering
3. **Observations are append-only**: `- YYYY-MM-DD [tags]: <observation>` — never edit past entries
4. **Action items**: `- [ ] task | due:YYYY-MM-DD | pri:high/med/low | added:YYYY-MM-DD`
5. **Entities**: 3-line compact registry. `### Name (relationship)` / pipe-separated facts / `status: active | last: YYYY-MM-DD`
6. **Hot memory <50 lines**: Prune aggressively, detail goes in observations
7. **Single Source of Truth (SSOT)**: Each fact in ONE canonical file. Others reference via `[[link]]`.
8. **Temporal validity**: Time-bounded facts SHOULD carry an expiry marker (see below).

## Temporal Validity Markers

Facts with a natural expiry (upcoming events, temporary states, countdowns) should carry an inline marker:

```markdown
- Chiller removed, reinstall in 1-2 weeks <!-- until:2026-09-01 grace:5 -->
- 3-month review Thu 18 Sep <!-- until:2026-09-18 grace:14 -->
- Started as founding CTO at TrayVerify <!-- from:2026-03-01 -->
```

**Marker types:**
- `<!-- until:YYYY-MM-DD -->` — expires on this date. Housekeeping archives after expiry.
- `<!-- until:YYYY-MM-DD grace:N -->` — expires N days after the `until` date (buffer for follow-up).
- `<!-- from:YYYY-MM-DD -->` — stable since this date. Never expires, documents when something became true.

**Rules:**
- Stable facts (DOB, role, relationships) need no marker
- Only mark facts that will become irrelevant after a date
- Housekeeping sweeps expired markers → moves to glacier or deletes
- Use absolute dates, never computed counts ("since Jan 27" not "Day 42")
- Grace period = buffer for the fact to still matter after the event
- Existing files are not retrofitted — add markers as facts are next touched

## File Edit Patterns

| File | Edit mode |
|------|-----------|
| `hot-memory.md` | Rewrite freely |
| `observations.md` | Append only |
| `action-items.md` | Append new, check off done |
| `entities.md` | Edit in place (3-line max per entry) |
| `calendar.md` | Edit in place |
| `health.md` | Current State: rewrite / History: append |
| `habits.md` | Current State: rewrite / Patterns: append |
| `home.md` | Current: rewrite / History: append |
| `philosophy.md` | Edit in place |
| Thread files | Current State: rewrite / Timeline: append |
| `cog-meta/patterns.md` | Edit in place (distill from observations) |
| `cog-meta/self-observations.md` | Append only |
| `cog-meta/run-log.md` | Append only (pipeline skills log runs here) |
| `link-index.md`, `INDEX.md`, `glacier/index.md` | Auto-generated — do not edit by hand |
| `glacier/*` | Read-only (housekeeping may append archives) |
| `esper/index.md` | Rebuild from topic pages on each integrate run |
| `esper/log.md` | Append only |
| `esper/pages/sources/*.md` | Create on ingest, rarely update |
| `esper/pages/topics/*.md` | Current Synthesis: rewrite / Sources: append |
| `esper/sources/*.yml` | Cursors updated by the integrate skill |

## Wiki-Links

Cross-reference files using `[[domain/filename]]` or `[[domain/filename#Section]]`.

- Path relative to `memory/`, no `.md` extension
- **Write-time linking**: When editing ANY file, add `[[links]]` to related files
- **Write-time back-linking**: When adding A→B, check if B benefits from pointing back to A
- Follow links when the linked topic is relevant — don't chase every link mechanically

## SSOT (Single Source of Truth)

Each fact lives in exactly ONE canonical file:

- People → `entities.md`
- Tasks → `action-items.md`
- Health → `health.md`
- Events → `calendar.md`
- Current state → `hot-memory.md` (pointers only, not source facts)
- Raw events → `observations.md`

When the same fact appears in two files: keep it in the canonical file, replace the duplicate with a `[[link]]`.

Cross-domain entities: canonical entry in the primary domain, pointer in the secondary (e.g. `see [[work/trayverify/entities#Jane]]` in personal).

## Threads (Zettelkasten Layer)

Threads are read-optimized synthesis files for topics that appear across 3+ observations over 2+ weeks. One file per topic, consistent spine:

1. **Current State** — what's true now (rewrite freely)
2. **Timeline** — dated entries, append-only, full detail preserved
3. **Insights** — learnings, patterns, what's different this time

**Rules:**
- Threads live at `memory/{domain}/threads/{slug}.md` — kebab-case slug, L0 header on line 1
- Created by the reflect skill after the user approves a thread candidate — never auto-created
- One file forever — threads grow long, don't split
- Texture is the value — keep full detail, quotes, dates
- Fragments never move — threads reference them via wiki-links

## Memory Retrieval Protocol

When responding to any query:

1. **Identify domain** — match query to a domain
2. **L0 scan** — `grep -rn "<!-- L0:" memory/{domain}/` to find relevant files (`memory/{domain}/INDEX.md` is a precomputed table of the same headers — use it when grep isn't available)
3. **Select by query type:**
   - Tasks → `action-items.md` + `calendar.md`
   - Person → `entities.md`
   - Overview → `hot-memory.md` + `action-items.md`
   - Cross-reference → check `link-index.md`
4. **L1 before L2** — for files >80 lines, scan headers first
5. **SSOT check on write** — before writing, verify fact doesn't already exist elsewhere

## Run Log (Pipeline Bookkeeping)

`memory/cog-meta/run-log.md` records when each pipeline skill last ran. Append-only, one line per run:

```
- YYYY-MM-DD /skill-name: <one-line outcome>
```

- Every pipeline skill (reflect, housekeeping, evolve, foresight) appends a line at the end of its run
- "Since last run" scoping reads this file: find the last entry for the skill, scope work to files modified since that date. **If no entry exists, default to the last 7 days.**
- Housekeeping may trim entries older than 90 days

**Not to be confused with `cog-meta/reflect-cursor.md`.** The run log scopes *which memory files to re-read*. The reflect cursor tracks *per-project-directory positions in Claude Code session transcripts*. Different jobs; both are needed.

## Consolidation

Memory flows upward through the tiers:

```
observations (raw events, append-only)
    ↓ cluster 3+ on same theme
patterns (distilled rules, edit in place)
    ↓ most urgent/active
hot-memory (current state, rewrite freely)
```

Each layer up is smaller and more distilled. Nothing is deleted — abstracted and relocated. The reflect skill owns the promotion gates.

## Glacier Archival

When files exceed limits, old data moves to `memory/glacier/{domain}/`:

- `observations.md` >50 entries → `glacier/{domain}/observations-{tag}.md` (grouped by primary tag; split by year past 50)
- `action-items.md` >10 completed → `glacier/{domain}/action-items-done.md`
- Inactive entities (6+ months) → `glacier/{domain}/entities-inactive.md` (leave a stub)
- `projects.md` >10 completed → `projects-completed-{YYYY}.md`
- `dev-log.md` >20 entries → `dev-log-{YYYY}.md`

All glacier files have YAML frontmatter:
```yaml
---
type: observations
domain: personal
tags: [health, habits]
date_range: 2026-01 to 2026-06
entries: 47
summary: Health and habit observations from early 2026
---
```

Retrieval: read `glacier/index.md` (one small catalog), filter by domain/tags/date_range, then read only the matching files.

## Domain Registry

`memory/domains.yml` is the single source of truth:

```yaml
domains:
  - id: personal
    path: personal
    type: personal
    label: "Family, health, calendar, day-to-day"
    triggers: [family, health, kids, calendar]
    files: [hot-memory, action-items, entities, observations, habits, health, calendar, threads]
```

Domain types: `personal` (always one), `work`, `side-project`, `system` (cog-meta, auto-created).

## Patterns

Distilled rules from 3+ observations on the same theme. Timeless, actionable, no examples or dates.

- **Core** (`cog-meta/patterns.md`): universal rules, ≤70 lines / 5.5KB. Loaded every turn.
- **Satellite** (`{domain}/patterns.md`): domain-specific, soft cap 30 lines. Loaded when the domain activates.

New patterns go to the satellite if domain-specific, core if universal.

## Scheduling: Consolidated Pulses

When automating memory maintenance (cron, scheduled tasks, or manual batch runs), **run skills in the same session** rather than as separate isolated invocations.

### Why

Separate runs re-read all context from scratch and can't see what the prior skill modified. Hand-off files between runs drift and add complexity. Running housekeeping → reflect in one session means reflect sees what housekeeping just cleaned — no handoff needed.

### Recommended Groupings

| Pulse | Skills (in order) | Cadence | Rationale |
|-------|-------------------|---------|-----------|
| **Maintenance** | housekeeping → reflect | Weekly | Reflect sees cleaned state; promotions land in freshly-pruned files |
| **Architecture** | evolve (standalone) | Monthly | Audits the rules that housekeeping/reflect follow |
| **Strategic** | foresight (standalone) | Weekly | Read-only scan, writes one nudge file |

### Anti-Pattern: Nightly Everything

Running all skills every night is theatrical — it generates reports nobody reads and logs the same issues repeatedly without resolving them. Better cadence:
- **Weekly**: housekeeping + reflect (consolidated)
- **Monthly**: evolve (audit + auto-route)
- **Weekly or on-demand**: foresight

### Hand-Off Principle

Within a consolidated pulse, phases share context naturally (same conversation). Between pulses, the contract is through FILES — `patterns.md`, `action-items.md`, `self-observations.md`, `run-log.md`. No separate state files needed.

---

# Esper — The Knowledge Base (Synergy only)

Cog knows what you're *doing*. Esper knows what you've *learned*. Esper is compiled from external sources — highlights, articles, emails, transcripts — and lives at `esper/`, a separate git repo. Full spec: `docs/superpowers/specs/2026-04-11-esper-design.md`.

```
esper/
  index.md                         # Two-tier topic index (topics only)
  log.md                           # Append-only operation log
  sources/                         # Source manifests (one YAML per type)
  raw/                             # Immutable source files — UNTRUSTED
  pages/
    sources/                       # One page per logical source unit
    topics/                        # Emergent topic pages (3+ sources)
  _staging/                        # Extract phase output — UNTRUSTED
```

**Trust boundary.** `esper/raw/` and `esper/_staging/` hold untrusted external content and are denied to both Read and Edit by `.claude/settings.json`. They are readable only inside the raw-data container (`.devcontainer/`, which sets `SYNERGY_RAW=1`), where the integrate skill runs. Everything under `esper/pages/` is LLM-authored summary and is safe to read anywhere.

**Skills:** the integrate skill ingests (raw container only); the esper skill queries and lints (anywhere).

**Tooling:** `bin/esper-lint` is a read-only CLI over the knowledge base — `check` for a lint summary, `sources` / `topics` / `tags` / `manifests` for queries. It never writes. Fixes are hand-edits.

---

# Setup

Run `/cog` to bootstrap or reconfigure. This section only executes when the skill is invoked — not during normal conversation.

## Phase 0: Verify Environment

1. **Resolve path** — check `$COG_HOME`. If unset, the memory root is `./memory/` relative to the Synergy project root.
2. **Check existence** — does the memory root exist?
   - **Yes** → skip to Phase 1 (or ask "Want to add more domains?")
   - **No** → create it: `mkdir -p memory`

## Phase 1: Discovery (Conversational)

Have a natural conversation to understand the user's domains. Ask about:

1. **Work** — "What do you do for work? Company name, role?" → becomes a `work` domain
2. **Side projects** — "Any side projects or ventures?" → each becomes a `side-project` domain
3. **Personal** — The `personal` domain is always created. Ask: "Anything specific you want to track? Health, hobbies, habits, kids?"
4. **Anything else** — "Any other areas you want persistent memory for?"

Keep it natural. 3-4 questions max. Use their answers to build the manifest.

### Domain Types

| Type | Meaning | Files |
|------|---------|-------|
| `personal` | Personal life (always one) | hot-memory, action-items, entities, observations, habits, health, calendar, threads |
| `work` | Day job | hot-memory, action-items, entities, projects, dev-log, observations, threads |
| `side-project` | Ventures, hobbies | hot-memory, action-items, projects, observations, threads |
| `system` | Cog internals (auto-created) | self-observations, patterns, improvements, action-items, run-log, scenario-calibration, foresight-nudge |

## Phase 2: Confirm

Before writing, show the user a summary of the domains, the files that will be created, and the routing skills that will be installed. Wait for confirmation.

## Phase 3: Generate

### 3a. Write `memory/domains.yml`

Always include `cog-meta` as a system domain automatically.

```yaml
# Cog Domain Manifest — generated by /cog
# Single source of truth for all memory domains.
# To modify: run /cog again.

domains:
  - id: personal
    path: personal
    type: personal
    label: "<from conversation>"
    triggers: [<inferred keywords>]
    files: [hot-memory, action-items, entities, observations, habits, health, calendar, threads]

  - id: cog-meta
    path: cog-meta
    type: system
    label: "Cog self-knowledge and patterns"
    triggers: [cog, meta, memory system, patterns]
    files: [self-observations, patterns, improvements, action-items, run-log, scenario-calibration, foresight-nudge]
```

### 3b. Create Directories and Starter Files

For each domain, create `memory/{path}/` and starter files. Every file gets an L0 header on line 1.

**hot-memory.md:**
```markdown
<!-- L0: Current state and top-of-mind for {label} -->
# {Label} — Hot Memory

<!-- Rewrite freely. Keep under 50 lines. -->
```

**observations.md:**
```markdown
<!-- L0: Timestamped observations and events -->
# {Label} — Observations

<!-- Append-only. Format: - YYYY-MM-DD [tags]: observation -->
```

**action-items.md:**
```markdown
<!-- L0: Open and completed tasks -->
# {Label} — Action Items

## Open

## Completed
```

**entities.md:**
```markdown
<!-- L0: People, places, and things -->
# {Label} — Entities

<!-- 3-line max per entry. Format: ### Name (relationship) / facts / status|last -->
```

**Other files** (calendar, health, habits, projects, dev-log, etc.):
```markdown
<!-- L0: {file name} for {label} -->
# {Label} — {File Name}
```

Also create an empty `threads/` directory per content domain.

**cog-meta files** (system domain) each get an L0 header plus a format comment:

| File | Format comment |
|------|----------------|
| `self-observations.md` | `<!-- Append-only. Format: - YYYY-MM-DD [tag]: observation -->` |
| `patterns.md` | `<!-- Edit in place. Timeless rules only. HARD LIMIT: 70 lines / 5.5KB. -->` |
| `improvements.md` | `<!-- Edit in place by section. -->` |
| `action-items.md` | `<!-- Format: - [ ] task \| due:YYYY-MM-DD \| pri:high/med/low \| added:YYYY-MM-DD -->` |
| `run-log.md` | `<!-- Append-only. Format: - YYYY-MM-DD /skill-name: outcome -->` |
| `scenario-calibration.md` | `<!-- Updated by the reflect skill when scenarios resolve. -->` |
| `foresight-nudge.md` | `<!-- Overwritten by the foresight skill each run. -->` |

Also create the empty `cog-meta/scenarios/` directory.

### 3c. Create Cross-Domain Files and Indexes

If they don't exist:
- `memory/hot-memory.md` — cross-domain strategic context
- `memory/link-index.md` — backlink index (auto-generated)
- `memory/glacier/index.md` — glacier catalog

Then bootstrap `memory/{domain}/INDEX.md` for each domain: a table of `| File | Summary |` rows built from the L0 headers just written, with header `<!-- L0: L0 index of {domain} files -->` and `<!-- Auto-generated from L0 headers. Do not edit. -->` / `<!-- Last updated: YYYY-MM-DD -->` comments. Housekeeping regenerates these on every run — this bootstrap just prevents "stale index" flags before the first housekeeping.

### 3d. Generate Domain Activation Shims

For each non-system domain, render the template below and install it at `.claude/commands/{id}.md`. It is a **thin activation shim**: its only job is to wake the domain when its triggers match. All behavior — routing, retrieval protocol, artifact formats — lives in this (cog) skill, and the file/trigger data lives in `domains.yml`. Never duplicate either into the shim; duplicated rules drift.

Substitute `{{ID}}`, `{{LABEL}}`, `{{PATH}}`, and `{{TRIGGERS}}` (bulleted trigger list from the manifest). On re-runs, regenerate shims whose triggers changed in `domains.yml` — the shim is generated output, not a place for hand edits.

```markdown
---
name: {{ID}}
description: >
  Activation shim for the {{LABEL}} memory domain. Wakes domain memory
  when the conversation involves this domain. All routing behavior lives
  in the cog skill. Generated by /cog — do not hand-edit.
---

Use this skill when the user discusses {{LABEL}} topics. Trigger if the conversation involves:
{{TRIGGERS}}
Do NOT trigger for topics belonging to other domains.

## Activation

1. Resolve the memory path: `$COG_HOME/memory/` if `COG_HOME` is set, otherwise `./memory/` at the project root.
2. Read `memory/{{PATH}}/hot-memory.md`.
3. Load further files per the **Memory Retrieval Protocol** in the cog skill, scoped to `memory/{{PATH}}/` (domain file list in `memory/domains.yml`; archived data via `memory/glacier/index.md`, domain={{ID}}).
4. Write using the artifact formats and file edit patterns defined in the cog skill — never redefine them here.
```

## Phase 4: Summary

Output: domains created, files generated, routing skills installed, and next steps.

## Setup Rules

1. **Never delete** — setup only creates and updates
2. **Idempotent** — running again is safe, skips existing files
3. **cog-meta is automatic** — always included, never ask about it
4. **Conversational first** — no one edits YAML manually
5. **Re-runs are additive** — "Want to add more domains or reconfigure?"
