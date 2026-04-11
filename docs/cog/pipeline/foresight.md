# Foresight

**Run:** Manually with `/foresight`, or automate via cron
**Role:** Strategist
**Introduced:** [Day 23](/journal/strategic-foresight)

## Why Foresight Exists

Every other pipeline step looks *backward* — what happened, what broke, what drifted. No step was looking *forward*: projecting trajectories, detecting stalls, finding cross-domain convergences that no single conversation would notice.

Foresight fills that gap.

## What It Does

Foresight reads broadly across all domains and produces **one strategic nudge per day**. It writes to `foresight-nudge.md`, which can be consumed by briefings or reviewed directly.

### The Five Lenses

1. **Cross-domain convergence** — finds situations where two or more domains are heading toward the same moment, deadline, or decision. Example: an overseas trip (personal) converging with a family member's medical recovery (health) and mid-year work leave (career).

2. **Velocity & stall detection** — identifies patterns that are moving fast (and might need steering) or have stalled (and need a nudge). Measures by observation density and action-item velocity.

3. **Timing awareness** — overlays calendar events and deadlines to find windows of opportunity or conflict. Uses calendar data for real schedule grounding.

4. **Pattern projection** — extends observed patterns forward. "If this continues, then..." — with calibrated confidence based on past accuracy.

5. **Synthesis** — distills the most actionable insight into one clear nudge.

### Scenario Candidate Detection

When pattern projection reveals a genuine fork — two meaningfully different paths with real stakes and a closing decision window — Foresight flags it as a candidate for [Scenario Simulation](/pipeline/scenarios).

## Rules

- **One nudge per day.** Not a list. One actionable insight.
- **Non-obvious only.** If it's already in hot-memory or action-items, it's not a nudge — it's a reminder. Foresight surfaces what isn't being tracked.
- **Read-only.** Foresight NEVER edits memory files. It reads broadly and writes only to `foresight-nudge.md`. If it spots a memory error, it notes it in the nudge for [Reflect](/pipeline/reflect) to handle.
- **Calendar-grounded.** Every nudge must reference real dates and deadlines, not abstract concerns.

## Anti-Patterns

- Repeating what the briefing already covers (stale items, birthdays)
- Generic advice ("remember to plan ahead")
- Non-actionable observations
- Nudges about Cog's own architecture (that's [Evolve](/pipeline/evolve)'s domain)

## Output

`foresight-nudge.md` — overwritten each run. One nudge with context, rationale, and a suggested action.
