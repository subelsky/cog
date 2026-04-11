# Evolve

**Run:** Manually with `/evolve`, or automate via cron
**Role:** Architect
**Introduced:** [Day 12](/journal/evolve-pipeline)

## Orientation

Before auditing, evolve runs a shell orientation pass — `find -mtime -1`, `wc -c`, `git diff --stat` — to measure file sizes and recent changes. L0 summaries are extracted via `grep -rn "<!-- L0:" memory/{domain}/` instead of loading INDEX.md files. Per-run cost is tracked and compared across sessions. See [Unix Toolbox Orientation](/journal/unix-toolbox-orientation).

## What It Does

Evolve audits Cog's architecture — the rules, processes, and prompt structure that govern the memory system. It does NOT touch memory content. It changes the rules that govern how content moves.

### Core Tasks

1. **Prompt weight analysis** — measures every component injected into the system prompt: hardcoded text, memory router index, hot-memory, patterns, briefing-bridge. Tracks changes run-over-run in a table. Target: minimize per-turn cost while preserving routing accuracy.

2. **Rule effectiveness** — reviews the latest housekeeping and reflect output. Did the rules produce the right behavior? Did any rule fail? Did any stage overstep its boundaries?

3. **File audit** — counts active and glacier files, total memory footprint. Flags anomalies (files growing past thresholds, dead files, zombie references).

4. **Process effectiveness** — verifies the pipeline ran in correct order, each stage completed, no overlaps or failures. Tracks consecutive clean runs.

5. **Rule changes** — proposes and applies changes to skill definitions (`.claude/commands/*.md`) and system instructions (`CLAUDE.md`). Low-risk changes (clarifications, cap adjustments) are applied directly. High-risk changes get proposed for user review.

## The Evolve Log

Every run produces a structured entry in `evolve-log.md`:

- Prompt weight table (component-by-component, with deltas)
- Files audited (count, footprint)
- Issues found (numbered, with root cause)
- Rule changes applied
- Rule changes proposed
- Process effectiveness assessment
- Routed content issues (for other stages to handle)
- Deferred items

This log is the first thing Evolve reads on the next run — continuity across sessions.

## Examples of Rule Changes

- **patterns.md hard cap:** After 3 cycles of re-bloating (20KB → 5.3KB → 5.8KB → 8.9KB), Evolve added a 100-line / 7KB cap with a 4-step compression protocol
- **Reflect boundary enforcement:** Reflect was modifying evolve-log.md (boundary violation) — Evolve added explicit file exclusions
- **Briefing-bridge template:** Housekeeping was adding day-by-day schedules despite the PURPOSE comment — Evolve fixed the template
- **Self-observation cap:** Reflect was producing 8+ observations per pass, causing rapid file growth — Evolve capped it at 5

## What It Doesn't Do

Evolve doesn't write observations, update entities, or condense content. It doesn't run housekeeping tasks. It changes the *rules* — not the *data*.

## Output

A debrief with the full structured entry. Updated skill definitions and instructions where changes were applied.
