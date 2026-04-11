# Pipeline

When you sleep, your brain doesn't shut off. It replays the day's events, strengthens the connections that matter, discards the noise, and reorganises everything into long-term memory. That's REM sleep — and Cog's pipeline is the AI equivalent.

Without maintenance, a memory system decays. Facts go stale. Summaries drift from their sources. Patterns emerge that no single conversation notices. The pipeline runs nightly to consolidate, reflect, and evolve — so every new session starts cleaner than the last.

| Stage | Role | What it does |
|-------|------|-------|
| [Housekeeping](/pipeline/housekeeping) | Janitor | Archive stale data, prune broken links, rebuild indexes |
| [Reflect](/pipeline/reflect) | Therapist | Mine conversations for patterns, detect contradictions, raise threads |
| [Evolve](/pipeline/evolve) | Architect | Audit the memory architecture itself, rewrite rules that aren't working |
| [Foresight](/pipeline/foresight) | Strategist | Cross-domain strategic nudge — what should you be thinking about tomorrow? |

Each step feeds the next. Zero overlap — one owner per job.

The pipeline was introduced incrementally: scheduler on [Day 2](/journal/scheduler-and-domains), reflection on [Day 6](/journal/the-architecture-day), evolve on [Day 12](/journal/evolve-pipeline), foresight and scenarios on [Day 23](/journal/strategic-foresight). The [domain registry](/journal/domain-registry) made the pipeline domain-agnostic — stages discover domains from `domains.yml` instead of hardcoded paths.

## Design Principle

**"Seeing ≠ owning."** When a pipeline step spots an issue outside its domain, it routes the issue — it doesn't adopt it. Housekeeping cleans; if it finds a pattern, it notes it for Reflect. Evolve changes rules; if it finds stale content, it routes to Housekeeping.

This prevents scope creep and keeps each stage focused.

## Scheduling

The pipeline is manual-first — run any skill as a slash command whenever you want. But for best results, automate it.

### Claude Code

Use cron to spawn one-shot Claude processes:

```bash
# Nightly maintenance
0 23 * * * cd /path/to/cog && claude -p "$(cat .claude/commands/housekeeping.md)"
0 0  * * * cd /path/to/cog && claude -p "$(cat .claude/commands/reflect.md)"

# Weekly architecture audit
0 1  * * 0 cd /path/to/cog && claude -p "$(cat .claude/commands/evolve.md)"

# Daily strategic nudge
0 7  * * * cd /path/to/cog && claude -p "$(cat .claude/commands/foresight.md)"
```

### Cowork

Open Cog in a [Cowork](https://claude.com/product/cowork) session and ask it to run pipeline skills as part of a longer autonomous workflow. Cowork has full file access and can chain multiple stages together — useful for a full maintenance pass in one session.
