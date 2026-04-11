# Reflect

**Run:** Manually with `/reflect`, or automate via cron
**Role:** Therapist
**Introduced:** [Day 6](/journal/the-architecture-day)

## Orientation

Before deep reads, reflect runs a shell orientation pass — `find -mtime -1`, `git diff --stat`, `grep -c` — to scope which files changed and where new observations landed. L0 summaries are extracted via `grep -rn "<!-- L0:" memory/{domain}/` instead of reading INDEX.md. This focuses the introspective pass on recently active material. See [Unix Toolbox Orientation](/journal/unix-toolbox-orientation).

## What It Does

Reflect is the introspective pass. It reads broadly, cross-references, and **acts** on insights — condensing observations into patterns, fixing contradictions, filling memory gaps, and updating entities.

This isn't passive observation. Reflect modifies files.

### Core Tasks

1. **Conversation mining** — reads recent conversation history and extracts unresolved threads, broken promises, friction points, and insights worth preserving.

2. **Observation → pattern promotion** — when 3+ observations cluster on the same theme, they get distilled into `patterns.md` (edit-in-place, timeless rules only). `patterns.md` has a hard cap of 110 lines / 7KB — enforced by a 4-step compression protocol.

3. **Hot-memory triage** — checks if anything in hot-memory has resolved or lost urgency. Demotes resolved items, promotes newly urgent patterns.

4. **Contradiction detection** — systematic consistency sweep across memory. For each domain's hot-memory, verifies claims against canonical sources. Resolution rules:
   - Canonical file always wins
   - More recent source wins
   - More specific wins over summary
   - Health dates and family-sensitive facts get flagged for user review, not auto-fixed

5. **Scenario feedback loop** — scans active [scenarios](/pipeline/scenarios) for check-by dates. If a scenario's check date has arrived, reflect reviews what actually happened against what was predicted, writes a retrospective, and updates calibration metrics.

6. **Self-observation** — after processing, appends up to 5 high-signal observations about Cog's own effectiveness to `self-observations.md`.

## The Contradiction Problem

This is why Reflect exists. A personal AI that tracks real people, dates, and events across months will inevitably have facts update in one file but not propagate to others. Example: a task status advances from "need documents" to "submitted" in action-items.md, but hot-memory still says "need documents."

Reflect catches these — 11+ instances per month on average.

## What It Doesn't Do

Reflect doesn't change rules or system architecture. If it finds a rule that isn't working, it notes it for [Evolve](/pipeline/evolve). It doesn't clean or archive — that's [Housekeeping](/pipeline/housekeeping).

## Output

A debrief summarizing what was learned, changed, and flagged. Modified memory files across all domains.
