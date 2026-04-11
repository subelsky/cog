# Scenarios

**Run:** On demand (user-triggered or Foresight-suggested) via `/scenario`
**Role:** Simulator
**Introduced:** [Day 23](/journal/scenario-simulation)

## Why Scenarios Exist

Cog can track facts and surface patterns, but it couldn't model *interactions between* isolated data. When a decision has real stakes and multiple possible outcomes, the right tool isn't a nudge — it's a simulation.

Scenarios model decision branches with real dependencies, calendar-grounded timelines, and a feedback loop that improves accuracy over time.

## How It Works

### 1. Decision Point Identification

Not everything deserves a scenario. The trigger threshold: a genuine fork with 2+ meaningfully different paths, real stakes, and a closing decision window. If the "branches" are just variations of the same outcome, it's not a real fork.

### 2. Dependency Mapping

Read across memory to identify all variables that influence the decision:

- **Calendar constraints** — deadlines, events, travel, work schedules
- **People involved** — who has influence, who needs to know, who is affected
- **Financial implications** — costs, budgets, opportunity costs
- **Health/energy factors** — medical appointments, recovery timelines, stress load
- **Existing commitments** — action items that overlap or conflict

### 3. Branch Generation

Generate 2–3 distinct branches (not exhaustive — focused). Each branch gets:

- A clear label and one-sentence summary
- Key assumptions that make this branch likely
- Concrete next steps if this branch is chosen
- **Canary signals** — early indicators that this branch is becoming reality

### 4. Timeline Overlay

Map each branch onto the actual calendar. Real dates, not abstract timelines. Flag conflicts, windows, and dependencies on external events.

### 5. Contingency Mapping

For each branch, identify what breaks if it doesn't happen. What's the fallback? What irreversible commitments does each branch create?

### 6. Write Scenario File

Each scenario is a markdown file in `memory/cog-meta/scenarios/` with YAML frontmatter:

```yaml
status: active
decision: What decision is being modeled
check-by: YYYY-MM-DD   # When to first review against reality
resolution-by: YYYY-MM-DD  # When this should be resolved
confidence: 0.0-1.0    # Calibrated against past accuracy
```

## The Feedback Loop

This is what makes scenarios a learning system, not just a one-shot tool.

1. **[Foresight](/pipeline/foresight)** detects scenario candidates during its daily scan
2. **User or Foresight** triggers `/scenario` to build the simulation
3. **[Reflect](/pipeline/reflect)** checks active scenarios at their `check-by` dates
4. If resolved, Reflect writes a retrospective: which branch happened, what was predicted, what was missed
5. Calibration metrics update in `scenario-calibration.md` — accuracy %, common blind spots, pattern of over/under-confidence
6. Future scenarios adjust their confidence based on calibration history

Over time, Cog gets better at projecting because it's measured against reality.

## Why Not Scheduled?

Unlike [Foresight](/pipeline/foresight) (which can run daily), scenarios are only valuable at genuine decision points. Running them on a schedule would be waste. They're event-driven: triggered when a real fork appears.

## Output

A scenario file in `memory/cog-meta/scenarios/` with branches, timelines, assumptions, canary signals, and contingencies. Flagged when check-by dates arrive or resolution-by dates pass.
