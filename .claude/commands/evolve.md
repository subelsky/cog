---
name: evolve
description: >
  Audit memory architecture, review rule effectiveness, measure metrics, and
  route threshold breaches to action items. Trigger on "evolve", "system
  audit", "audit yourself", "check your architecture". Run monthly.
---

# Cog Evolve

Systems-level self-improvement. The architect.

**This is NOT the reflect skill.** Reflect = "what did I learn?" Evolve = "are the rules working?" **Evolve never touches memory content — it changes the rules that govern how content moves.**

The rules under audit live in the **cog skill** (`.claude/commands/cog.md`) and the pipeline skills. Evolve may edit those; it may not edit `memory/` content.

## Memory Path

All files under the resolved memory path: `$COG_HOME/memory/` if `COG_HOME` is set, otherwise `./memory/` at the project root.

## Minimum Data Check

Before auditing, verify the system has enough history:

- Reflect has never run (no self-observations, no patterns) → **stop.** "Nothing to audit yet. Run the reflect skill a few times first to build patterns, then evolve can assess whether they're working."
- `patterns.md` has <3 entries → "Too few patterns to evaluate effectiveness. Let the system run for a few more cycles."

Evolve audits rules — there need to be rules to audit.

## Files to Read

Continuity (read first):

- `memory/cog-meta/run-log.md` — when housekeeping / reflect / foresight actually last ran. Scope this audit to what changed since the last `/evolve` entry (no entry → last 30 days).
- `memory/cog-meta/self-observations.md` — what's been noticed
- `memory/cog-meta/patterns.md` — the current rules
- `memory/cog-meta/action-items.md` — open `[evolve]` items from prior runs

Architecture reference (the rules themselves):

- `.claude/commands/cog.md` — conventions SSOT
- `.claude/commands/housekeeping.md`, `.claude/commands/reflect.md` — pipeline rules
- `CLAUDE.md` — routing and cadence

Measure (never edit the content):

- `memory/hot-memory.md` and each domain's `hot-memory.md`
- Any domain satellite `patterns.md`
- Domain `INDEX.md` freshness

### Orientation shortcut

`memory/` is a git repo. Diffs are cheaper than re-reading whole files:

```bash
git -C memory diff --stat @{30.days.ago}          # what housekeeping/reflect changed
git -C memory diff @{30.days.ago} -- cog-meta/patterns.md hot-memory.md
wc -c memory/hot-memory.md memory/cog-meta/patterns.md
```

## Process

### 1. Architecture Review

Evaluate structural design:

- **Tier design** — are the hot / warm / glacier boundaries well-defined and respected?
- **Consolidation pipeline** — is the flow working? Where does it stall or leak?
- **File organization** — files in the wrong domain? Orphaned files? Domains in `domains.yml` with no directory, or vice versa?
- **Skill boundaries** — are the housekeeping / reflect / evolve lanes clean, or is one doing another's job?
- **Convention drift** — does any skill restate a rule that the cog skill owns? Duplicated rules drift; route them to be replaced by a reference.

### 2. Process Effectiveness Audit

**Housekeeping check:**

- Did the pruning priority order trim the right things?
- Are the glacier thresholds (50 observations, 10 completed items) right?
- Is the 50-line hot-memory cap appropriate?
- Are generated indexes actually being regenerated, with L0 on line 1?

**Reflect check:**

- Did the consolidation gates produce useful patterns or noise?
- Did any cluster pass all three gates? If none ever do, the gates are miscalibrated for this data volume.
- Did thread candidate detection fire, and did the user act on it?
- Is reflect staying in its lane?

**Scorecard metrics:**

| Metric | Target |
|---|---|
| Core `patterns.md` line count / 70 (and bytes / 5.5KB) | ≤1.0 |
| Each satellite `patterns.md` line count | ≤30 |
| Entity compression ratio (total entity lines / `###` entries) | ≤3.0 |
| Each `hot-memory.md` line count | ≤50 |
| Domain `INDEX.md` age (last-updated vs today) | ≤14 days |
| Expired-but-unswept temporal markers | 0 |
| Pipeline runs missing from `run-log.md` vs stated cadence | 0 |

If `INDEX.md` files don't exist yet, that's absence, not staleness — route one item: "Run the housekeeping skill to generate domain indexes."

### 3. Auto-Route on Threshold Breach

This is the difference between theatrical evolve (reporting problems) and effective evolve (resolving them). When a metric breaches, **create a concrete action item** — not an observation.

| Metric | Threshold | Action |
|---|---|---|
| `patterns.md` line ratio > 1.0 | Exceeds 70 lines | → `cog-meta/action-items.md`: "Merge or replace patterns to bring below 70 lines" |
| Satellite pattern file > 30 lines | Exceeds soft cap | → domain `action-items.md`: "Compress {domain} patterns" |
| Entity compression > 3.0 | Entries too verbose | → domain `action-items.md`: "Compress entities or promote to threads" |
| Hot-memory > 50 lines | Exceeds cap | → domain `action-items.md`: "Prune hot-memory (run the housekeeping skill)" |
| `INDEX.md` > 14 days stale | Drift risk | → `cog-meta/action-items.md`: "Rebuild domain indexes (run the housekeeping skill)" |
| Expired temporal markers > 0 | Stale facts | → `cog-meta/action-items.md`: "Sweep expired temporal markers (run the housekeeping skill)" |
| Same issue in self-observations 3+ times | Recurring, unresolved | → escalate: propose a rule change that prevents recurrence |

**Format for auto-routed items:**

```
- [ ] [evolve] {description} | due:YYYY-MM-DD | pri:med | added:YYYY-MM-DD
```

The `[evolve]` tag marks items this skill created. If an `[evolve]` item already exists for the same metric, update it — don't duplicate.

**Key principle:** logging an observation about a problem for the third time is a rule failure. Stop observing and start fixing.

### 4. Rule Change Proposals

For each proposal, state: what problem it solves, what evidence supports it, what the risk is, and whether it is a rule change or an architecture change.

**Apply low-risk rule changes directly** to the owning skill file. **Propose architecture changes** for user review — don't apply them unasked.

A rule change belongs in exactly one file. If the rule is a convention, it belongs in the cog skill and the pipeline skills reference it.

### 5. Route Content Issues

Content problems that aren't threshold breaches get routed, not fixed:

```
→ housekeeping: entities.md at 290 lines, needs a glacier pass
→ reflect: hot-memory missing a link for X
→ reflect: patterns.md carries stale snapshot data from February
```

If the same issue keeps reappearing across runs, that's a rule problem — propose a fix (step 4) instead of routing it again.

### 6. Write Observations

Append to `memory/cog-meta/self-observations.md`:

- Format: `- YYYY-MM-DD [tag]: observation`
- Tags: `bloat`, `staleness`, `redundancy`, `gap`, `architecture`, `opportunity`, `rule-drift`, `process-health`
- **Max 3 per run** — quality over quantity

### 7. Debrief

- *Scorecard* — the metrics table, current values vs targets
- *Actions created* — every item routed to an `action-items.md`, listed
- *Rule changes* — applied or proposed, with rationale
- *Process health* — did housekeeping / reflect / foresight run on cadence and follow their own rules?
- *Architecture notes* — structural observations

Numbers over narrative. If nothing breaches, say so and stop — don't invent work.

Finally, append a run entry to `memory/cog-meta/run-log.md`:

```
- YYYY-MM-DD /evolve: <one-line outcome>
```
