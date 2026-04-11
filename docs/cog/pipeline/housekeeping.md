# Housekeeping

**Run:** Manually with `/housekeeping`, or automate via cron
**Role:** Janitor
**Introduced:** [Day 2](/journal/scheduler-and-domains)

## Orientation

Before reading any files, housekeeping runs a shell orientation pass — `find -mtime -1`, `grep -c`, `wc -c` — to identify which domains have changed since the last run. Domains with zero recent changes can be skimmed or skipped. L0 summaries are extracted via `grep -rn "<!-- L0:" memory/{domain}/` instead of loading INDEX.md files. See [Unix Toolbox Orientation](/journal/unix-toolbox-orientation).

## What It Does

Housekeeping is the maintenance pass. It cleans, archives, and surfaces accountability. The output feeds every subsequent pipeline stage.

### Core Tasks

1. **Glacier archival** — when observation files exceed 50 entries, the oldest batch gets archived to `glacier/` with YAML frontmatter for fast retrieval. Glacier files are never auto-loaded but remain searchable.

2. **Link audit** — scans memory files for wiki-links, generates `link-index.md` (a backlink index). This is the safety net for write-time linking — catching any cross-references that were missed.

3. **Briefing bridge** — writes `briefing-bridge.md` with critical findings: stale action items, upcoming birthdays, overdue health items, dormant domains.

4. **Thread candidate detection** — if a topic appears in 3+ observations across 2+ weeks, it suggests raising a [thread](/memory#threads--the-zettelkasten-layer).

### Accountability Surfacing

- **Stale items:** Action items open >2 weeks get flagged with a suggested next action
- **Health escalation:** Items open >6 months appear in every briefing until resolved or explicitly deferred
- **Birthday prep:** 14 days out = gift suggestions from entity interests. 7 days out = logistics check
- **Todo expiration:** Time-bound lists with <5 days left and >50% unchecked get flagged
- **Dormant domains:** Work domains with 0 observations in >4 weeks get questioned

## What It Doesn't Do

Housekeeping doesn't introspect, distill patterns, or change rules. If it finds a pattern, it notes it for [Reflect](/pipeline/reflect). If it finds a rule issue, it notes it for [Evolve](/pipeline/evolve).

## Output

A debrief summarizing what was cleaned, archived, and flagged. Plus `briefing-bridge.md` for downstream consumption.
