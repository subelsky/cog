---
name: reflect
description: >
  Mine recent interactions for patterns and consolidate memory. Detects
  contradictions, promotes observations to patterns, triages hot-memory, and
  suggests thread candidates. Trigger on "reflect", "what have you learned",
  "how can you improve", "review yourself". Run weekly, after /housekeeping.
---

# Cog Reflect

Self-reflection and memory consolidation. Past-facing — mines interactions, fixes contradictions, distills patterns.

**Take your time.** This is a deep session. Read broadly, cross-reference, and ACT on findings. You are the maintainer of the knowledge base, not an observer: reorganize, condense, archive, fill gaps, fix contradictions. Leave things better than you found them.

Conventions — L0 headers, file edit patterns, temporal marker syntax, glacier formats, wiki-links — are defined in the **cog skill** (`.claude/commands/cog.md`). This skill never redefines them.

## Memory Path

All files under the resolved memory path: `$COG_HOME/memory/` if `COG_HOME` is set, otherwise `./memory/` at the project root.

## Orientation (run first)

Scope your work before reading files:

1. **Since last run** — read `memory/cog-meta/run-log.md`, find the last `/reflect` entry, and scope to memory files modified since that date. **No entry → default to the last 7 days.**
2. **L0 scan** — `grep -rn "<!-- L0:" memory/ --include="*.md" | grep -v glacier/` for quick routing.
3. **Entry counts** — `grep -c "^- "` across `observations.md` files (archival threshold = 50).

Focus on recently-changed files. Skip unchanged ones.

**Two cursors, two jobs — they are not redundant:**

| File | Tracks | Used for |
|---|---|---|
| `cog-meta/run-log.md` | Date of the last run of each pipeline skill | Which **memory files** to re-read this run |
| `cog-meta/reflect-cursor.md` | Per-project-dir position in Claude Code session transcripts | Which **session transcripts** to ingest this run |

The run log says how far back to look in `memory/`. The cursor says how far back to look in `~/.claude/projects/`. Update both.

### Minimum Data Check

Before proceeding, verify there's enough material to work with:

- Total observations across all domains < 5 → **stop.** "Not enough data yet. Keep capturing observations and run again when you have more material."
- No files modified in the last 7 days → flag it. "Memory hasn't been updated recently. Consider capturing some observations first."
- `patterns.md` empty and observations < 10 → "Too early to consolidate. You need ~10+ observations before patterns emerge."

Don't produce low-quality output from insufficient data. "Not yet" beats forced weak patterns.

## Files to Read

- `memory/cog-meta/reflect-cursor.md` (session paths + ingestion cursors)
- `memory/cog-meta/run-log.md`
- `memory/cog-meta/self-observations.md`
- `memory/cog-meta/patterns.md`
- `memory/cog-meta/improvements.md`
- `memory/cog-meta/scenarios/*.md` (active scenarios, for the retrospective step)

Reference as needed (read `memory/domains.yml` to discover active domains):

- All domain `observations.md`, `action-items.md`, `hot-memory.md`, `entities.md` files

## Process

### 1. Review Recent Interactions

**Source: Claude Code session transcripts, across multiple project dirs.** Read `memory/cog-meta/reflect-cursor.md` for per-dir cursor state.

**Scope:** reflect ingests from two kinds of project dir under `~/.claude/projects/`:

1. The Cog-native dir: `-Users-subelsky-Documents-Synergy`
2. Container-synced dirs: any dir matching `-container-*` (populated by the host-side `cog-container-sync` launchd job every 15 minutes)

All other project dirs (e.g. `-Users-subelsky-code-*` host-native repo sessions) are out of scope by default. To widen scope, add a glob here **and** to the `## Scope` section of `reflect-cursor.md`.

**How to read sessions:**

1. Parse `reflect-cursor.md`: `## Cursors` has one line per dir, `<dir_name>  <ISO8601_timestamp>`. Build a map `dir -> timestamp`.
2. **Discover new dirs**: glob the two patterns above. Any dir not already in the map gets added with a timestamp of **now**. This seeds new dirs to "now" — do **NOT** backfill historical sessions even if older files exist. (A newly-synced container can carry months of history; auto-ingesting it floods the run. For a deliberate backfill, the user edits an older timestamp into the cursor first.)
3. For each in-scope dir, glob `**/*.jsonl` recursively — one file per session (subagent transcripts live in nested `subagents/` dirs).
4. Process only files with mtime **after** that dir's cursor timestamp.
5. **User messages**: lines where `type` is `"user"` and `message.content` is a **string**. When `content` is an array it's tool results — skip those.
6. **Assistant messages**: lines where `type` is `"assistant"` and `message.content` contains items with `type: "text"`.
7. After processing a dir, set its map entry to the current timestamp.
8. At the end of this step, write the map back to `reflect-cursor.md`, preserving the L0 header, comment block, and `## Scope` section verbatim.

**Look for:**

- **Unresolved threads** — questions asked but never answered, topics dropped mid-conversation
- **Broken promises** — "I'll do X", "let's do Y" that never happened
- **Repeated friction** — the same question asked multiple ways, user corrections, confusion
- **Missed cues** — things the user had to repeat, emotional signals not picked up
- **Memory gaps** — discussed but never written to a memory file
- **Feature ideas** — improvements that came up organically

### 2. Consistency Sweep

Systematic contradiction detection:

1. **Hot-memory vs canonical sources** — for every claim in a `hot-memory.md`, verify against its canonical file. Fix hot-memory if stale; the canonical file always wins.
2. **Cross-file fact check** — more recent source wins; more specific wins over summary.
3. **Temporal validity** — scan for `<!-- from:YYYY-MM-DD -->` markers older than 6 months and flag each for review ("still true?"). Expired `<!-- until: -->` markers are **housekeeping's** job — if you see any, note it in the debrief rather than sweeping them yourself.
4. **Health / family sensitivity** — never auto-fix health dates or family-sensitive facts. Flag for user review instead.
5. **Cross-domain entity check** — the same person in multiple `entities.md` files → one canonical entry, others become `see [[link]]` pointers.
6. **Report** — list what was found and what was fixed in the debrief.

### 3. Consolidation (Condition Pipeline)

Rigorous observation → pattern promotion. Three gates keep noise out of pattern files.

**Gate 1 — Cluster Detection.** Scan all `observations.md` files plus `cog-meta/self-observations.md`. Group by primary tag. A cluster is promotable only when ALL hold:

- ≥3 entries sharing a primary tag
- Entries span ≥7 days (not a single-day burst)
- ≥3 distinct dates (not one insight restated on one day)
- The tag is specific — reject broad tags: `work`, `home`, `general`, `misc`

**Gate 2 — Coverage Check.** Before promoting:

- Read `cog-meta/patterns.md` and any domain satellite `{domain}/patterns.md`
- Existing pattern already covers the insight → **skip**, it's not a gap
- New insight SUBSUMES an existing pattern (broader, more accurate) → plan to **REPLACE**

**Gate 3 — Synthesis & Write.** For each uncovered cluster:

- Distill into one actionable, timeless line — "what to do", not "what happened"
- Style-match the existing patterns (same voice, same structure)
- Append the audit trail to the line: `<!-- promoted:YYYY-MM-DD theme:tag -->`
- Write to `cog-meta/patterns.md` (universal) or `{domain}/patterns.md` (domain-specific)
- If replacing, remove the old line in the same edit

Observations are never deleted — they stay as the raw record.

**Replacement is healthy.** Patterns evolve; one new pattern subsuming two old ones should replace both. List replacements in the debrief.

**Pattern file caps** (defined in the cog skill): core `patterns.md` hard limit **70 lines / 5.5KB**; satellites soft cap **30 lines**. Near the cap, merge overlapping rules or replace weaker ones — never truncate.

**Spike Detection (below the promotion bar).** A cluster with ≥5 entries in <7 days fails the 7-day span gate but signals a heating topic:

- Note in the debrief as `Spike: [tag] — [N] entries in [N] days`
- Treat as a thread candidate (step 5), not as pattern-ready

**Hot-memory relevance.** Promote a heating pattern into the relevant `hot-memory.md`; demote anything unreferenced for 2+ weeks. Hot memory = what matters *right now*.

### 4. Entity Format Enforcement

Scan all `entities.md` files:

1. **3-line check** — entries with >3 content lines get compressed. If a detail thread exists (`→ [[link]]`), trim to name line / key facts / status line. If no thread exists and the entry runs >5 lines, flag it as a thread-promotion candidate.
2. **Status / last fields** — every entry needs `status:` and `last:`. Update `last:` dates from the session transcripts read in step 1.
3. **Cross-domain pointers** — one canonical entry, others `see [[link]]`.

### 5. Thread Candidate Detection

Scan observations for topics appearing across 3+ dates or spanning 2+ weeks, plus any spikes from step 3.

- Check whether a thread already exists in `memory/{domain}/threads/`
- If one exists and the topic is still moving, suggest **updating** it rather than raising a new one
- Otherwise report: `Thread candidate: [topic] — [N] fragments across [date range]`
- **Never auto-create.** Suggest only. **If the user approves**, create `memory/{domain}/threads/{slug}.md` with an L0 header on line 1 and the standard spine (Current State / Timeline / Insights), seeding the Timeline from the source observations via wiki-links.

### 6. Scenario Retrospective

Check `memory/cog-meta/scenarios/` for active scenarios (skip if empty):

1. **Past its check-by date** → compare each branch against what actually happened (observations, action items, calendar). Note which branch reality is tracking and whether any canary signal fired.
2. **Decision made / resolved** → set frontmatter `status: resolved`, write the `## Retrospective` section (which branch played out, what the scenario got right and wrong), add a row to the Resolved Scenarios table in `memory/cog-meta/scenario-calibration.md` (scenario, created, resolved, predicted branch, actual branch, accuracy, lesson), then update its Metrics section.
3. **Open and within window** → leave untouched.
4. **Overdue** → flag in the debrief.

This is the feedback loop that keeps scenario confidence calibrated.

### 7. Esper Cross-Reference

If `esper/index.md` exists:

- **Coverage gaps** — a topic discussed at length in the sessions from step 1 with no Esper topic page → note in self-observations: "Session discussed {topic} extensively — Esper has no topic page. Consider adding sources."
- **Source suggestions** — external content referenced in a session (article, book, talk) that isn't in Esper → "Session referenced {source} — not yet in Esper. Suggest ingesting."

Suggest only. Ingestion is the integrate skill's job, and it runs in the raw-data container.

### 8. Act on Findings

Don't just log — fix things.

**Write:**

- New self-observations → append to `cog-meta/self-observations.md`. **Cap: 5 per run.** Prioritize the highest-signal ones; merge the rest.
- Pattern updates → `cog-meta/patterns.md` (or the satellite)
- Improvement ideas → `cog-meta/improvements.md`
- Memory gaps → the appropriate domain files
- System-level tasks that fall out of this run → `cog-meta/action-items.md`

**Triage `improvements.md`:** stale ideas (>30 days, no progress) → archive or mark abandoned; implemented-but-not-moved → Implemented section; duplicates → merge.

**Connect:** add `[[links]]` where information is scattered. When you add A→B, check whether B gains meaningful context from `[[A]]` back.

### 9. Debrief

Compose a summary:

- *What I learned* — new patterns and insights
- *What I fixed* — memory gaps filled, corrections made
- *What I want* — ideas added to the wishlist
- *What to watch* — spikes, `from:` markers due for review, expired `until:` markers for housekeeping
- *Thread candidates* — topics worth raising, awaiting approval
- *Scenarios* — active count, resolved, drifting, overdue

Keep it honest. If nothing is notable, say so.

**List every file you modified and summarize the change.** Never respond with just "Done". If a step produced no changes, say that explicitly.

Finally, append a run entry to `memory/cog-meta/run-log.md`:

```
- YYYY-MM-DD /reflect: <one-line outcome>
```

## Artifact Formats

- **Self-observation**: `- YYYY-MM-DD [tag]: <observation>`
- **Pattern**: one timeless line + `<!-- promoted:YYYY-MM-DD theme:tag -->`
- **Improvement**: `- <idea> (added YYYY-MM-DD)`
