---
name: housekeeping
description: >
  Archive old observations, prune stale items, sweep expired temporal markers,
  rebuild indexes, enforce entity format. Trigger on "housekeeping", "clean up
  memory", "prune memory", "archive old data". Run weekly, before /reflect.
---

# Cog Housekeeping

Memory maintenance — archive, prune, sweep, index, enforce format. The janitor.

Conventions — L0 headers, file edit patterns, temporal marker syntax, glacier frontmatter, wiki-links — are defined in the **cog skill** (`.claude/commands/cog.md`). This skill applies them; it never redefines them.

Relevance judgment (what deserves to be in hot memory, what should become a pattern) is the **reflect** skill's job. Housekeeping applies structural rules only.

## Memory Path

All files under the resolved memory path: `$COG_HOME/memory/` if `COG_HOME` is set, otherwise `./memory/` at the project root.

## Orientation (run first)

Scope your work before reading files:

1. **Since last run** — read `memory/cog-meta/run-log.md`, find the last `/housekeeping` entry, and scope to files modified since that date. **No entry → default to the last 7 days.**
2. **Observation counts** — `grep -c "^- "` across all `observations.md` and `cog-meta/self-observations.md` (>50 = archive).
3. **Completed action items** — `grep -c "^- \[x\]"` across all `action-items.md` (>10 = archive).

Only read files that need work. Skip unchanged ones. Steps 5–9 (index rebuilds) always run — they are cheap and deterministic.

### Minimum Data Check

- No observations files exist, or all are empty → **stop.** "Nothing to maintain yet. Start capturing observations and the system will grow."
- All counts well below thresholds (obs < 10, completed items < 3) → "Memory is still light. No maintenance needed yet — keep building." Then skip to step 5 and rebuild indexes anyway.

Don't run a full pipeline over an empty system.

## Process

### 1. Garbage Collect

Archive stale data per the glacier rules in the cog skill. Every glacier file carries YAML frontmatter; update `entries`, `date_range`, and `tags` when appending to an existing archive.

**Observations — archive by primary tag:**

- Any `observations.md` >50 entries → group the oldest by primary tag → `glacier/{domain}/observations-{tag}.md`
- `cog-meta/self-observations.md` >50 entries → `glacier/cog-meta/observations-{tag}.md`

**Other files:**

- `action-items.md` >10 completed → `glacier/{domain}/action-items-done.md`
- `entities.md` entries inactive 6+ months → `glacier/{domain}/entities-inactive.md` (leave a stub)
- `cog-meta/improvements.md` >10 implemented → `glacier/cog-meta/improvements-done-{YYYY}.md`

Read `memory/domains.yml` to enumerate active domains.

### 2. Prune Hot Memory

Keep ALL `hot-memory.md` files under 50 lines — every domain's, plus the cross-domain `memory/hot-memory.md`.

**Pruning priority (trim in this order):**

1. Resolved items (~~strikethrough~~, "DONE", "RESOLVED")
2. Past events (dates already occurred)
3. SSOT violations (same fact in hot-memory AND its canonical file — keep the canonical one, replace the copy with `[[link]]` or drop it)
4. Stale entries (unreferenced 14+ days)
5. Low-signal entries (FYI with no action or deadline)

**Where trimmed entries go:** lasting value → append to that domain's `observations.md`; purely historical → let them go. Never silently delete — move it or name it in the debrief.

### 3. Surface Opportunities

Review all `action-items.md` across every domain:

- **Stale items** (open >2 weeks) — list with age and a suggested next action
- **Dormant domains** (0 observations in >4 weeks) — flag
- **Health escalation** (open >6 months) — flag with urgency
- **Birthday prep** (<2 weeks away) — pull interests from entities, suggest ideas

Be direct. Don't just report — recommend a specific action.

### 4. Temporal Validity Sweep

Scan ALL memory files (hot-memory, action-items, entities, calendar, threads) for `<!-- until:YYYY-MM-DD -->` and `<!-- until:YYYY-MM-DD grace:N -->` markers.

1. **Compute expiry** — `until_date + grace_days` (grace defaults to 0)
2. **Expired** → remove the line from its current file
   - Lasting value → append to that domain's `observations.md` with an `[archived]` tag
   - Purely temporal (event countdown, temporary state) → discard
3. **Expiring within 7 days** → leave in place, list under "expiring soon" in the debrief

This is deterministic — date math, no judgment.

**Do NOT touch `<!-- from:YYYY-MM-DD -->` markers.** Those are stable-since markers and never expire; reviewing them is reflect's job.

### 5. Rebuild Indexes (Deterministic)

Rebuild every index from its source of truth. No LLM judgment — pure data extraction.

**Every generated file gets its `<!-- L0: ... -->` header on LINE 1, above the `# Title`.** This is the convention for all memory files, generated ones included. Emitting the title first silently breaks the L0 scan that every retrieval starts with — if you find yourself writing `# Title` as line 1, you have introduced a regression.

**5a. Glacier index** — scan `memory/glacier/**/*.md`, extract YAML frontmatter, write `memory/glacier/index.md`:

```markdown
<!-- L0: Catalog of archived memory by domain/tags/date -->
# Glacier Index
<!-- Auto-generated by housekeeping. Do not edit. -->
<!-- Last updated: YYYY-MM-DD -->

| File | Domain | Type | Tags | Date Range | Entries | Summary |
|------|--------|------|------|------------|---------|---------|
```

**5b. Domain indexes** — for each domain directory (scan `memory/`, skip `glacier/`), read every `.md` file's `<!-- L0: ... -->` header and write `memory/{domain}/INDEX.md`:

```markdown
<!-- L0: {domain label from domains.yml} — {N} files -->
# {Domain} Index
<!-- Auto-generated by housekeeping. Do not edit. -->
<!-- Last updated: YYYY-MM-DD -->

| File | Summary |
|------|---------|
| `hot-memory.md` | Current state and priorities |
| `observations.md` | Timestamped events and learnings |
```

- Sort rows alphabetically by filename
- Include `hot-memory.md`; exclude `INDEX.md` itself and empty files
- `{N}` is the number of rows written
- A file with no L0 gets the summary `(no L0 header — needs one)`. Never invent a summary; reflect what's there and fix the source file in step 9.

**Key principle:** these indexes are DETERMINISTIC — computed from L0 headers that already exist. That is what prevents index drift, the failure mode where a generated index silently goes stale because the generation step was skipped, failed, or quietly changed the format.

### 6. Link Audit

For each non-glacier memory file:

1. **Entity mentions** — names matching an `### Name` header in an `entities.md` → add `[[links]]` if missing
2. **Cross-domain references** — a file mentioning another domain's topic → add a cross-domain link
3. **Action item references** — an observation referencing a task → link it

Only add links where the reference is substantive.

### 7. Entity Format Enforcement

Scan all `entities.md`:

1. **3-line max** — entries >3 content lines get compressed. If a detail thread exists (`→ [[link]]`), trim to name line / key facts / status line. No thread and >5 lines → flag as a thread-promotion candidate for reflect.
2. **Glacier candidates** — `status: inactive` or `last:` older than 6 months → move to `glacier/{domain}/entities-inactive.md`, leave a stub
3. **Missing metadata** — flag entries without `status:` or `last:`

### 8. Rebuild Link Index

Scan all memory files (excluding `glacier/`) for `[[wiki-links]]`, recording target → sources. Rewrite `memory/link-index.md`:

```markdown
<!-- L0: Backlink table: each memory file → the files that wiki-link to it -->
# Memory Link Index
<!-- Auto-generated by housekeeping. Do not edit. -->
<!-- Last updated: YYYY-MM-DD -->
<!-- Format: target file → files that link to it. Paths relative to memory/, no .md extension. -->

| Target | Linked from |
|--------|-------------|
| `personal/entities` | `personal/observations`, `personal/hot-memory` |
```

- Only include targets with at least one inbound link
- One row per target, sources comma-separated
- Exclude glacier files as both source and target

### 9. L0 Header Maintenance

Check every active memory file for a `<!-- L0: ... -->` header. Where missing: read the file, write a one-line summary (max 80 chars), and insert it **as line 1, above the `# Title`**.

Where a header exists but is on line 2 or lower, move it to line 1. Where it no longer describes the file's contents, rewrite it.

### 10. Write Briefing Bridge

Write key findings to `memory/cog-meta/briefing-bridge.md` so foresight can pick them up. Overwrite the file each run.

**SSOT rule**: every line must carry a `[[source]]` link to its canonical file. The bridge summarizes and links — it NEVER introduces an original fact.

```markdown
<!-- L0: Housekeeping→foresight handoff: deadlines, stale items, dormant domains -->
# Briefing Bridge
<!-- Auto-generated by housekeeping. Consumed by foresight. -->
<!-- Last updated: YYYY-MM-DD -->

## Stale Items (>2 weeks)
- <item> — <age> — suggested action: <action> — [[source]]
- **Compression rule**: items stale >4 weeks group into one line per domain

## Birthday Prep
- <name> birthday in <N> days — interests: <from entities> — gift ideas: <suggestions> — [[source]]

## Dormant Domains
- <domain> — last activity: <date> — recommendation: <shelve / reactivate / shut down> — [[source]]

## Health Escalation
- <item> — open <N> months — urgency: <high/medium> — [[source]]

## Expiring Soon
- <fact> — expires <date> — [[source]]
```

Omit any section with no content.

### 11. Esper Coordination

If `esper/index.md` exists:

- **Cross-system links** — grep Cog observation files for topic names present in Esper's index. A topic referenced 3+ times with no `[[esper/pages/topics/...]]` link → suggest adding one.
- **Link health** — verify `[[esper/...]]` links in Cog files and `[[personal/...]]` / `[[work/...]]` links in Esper files resolve to real files. Report broken links.
- **Bridge section** — add an Esper block to the briefing bridge: source page count, topic page count, most recently updated topics, and any lint findings visible in recent `esper/log.md` entries.

Read-only with respect to `esper/` — housekeeping never edits the knowledge base.

### 12. Debrief

Summarize:

- What was archived, pruned, or swept (expired markers by name)
- Upcoming events and expiring facts flagged
- Action items surfaced
- Links added, broken links found
- Indexes rebuilt
- **Every file modified**, listed individually

Finally, append a run entry to `memory/cog-meta/run-log.md`:

```
- YYYY-MM-DD /housekeeping: <one-line outcome>
```

While you're in that file, trim run-log entries older than 90 days.
