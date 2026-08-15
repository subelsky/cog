---
name: esper
description: >
  Query or health-check the Esper knowledge base. Trigger on "esper", "what do
  I know about", "search esper", "esper lint", "knowledge check". Runs
  anywhere — it reads only LLM-authored summary pages.
---

# Esper

Use this skill to query or health-check the Esper knowledge base. Trigger if the user says "esper", "what do I know about", "search esper", "esper lint", "knowledge check", or similar query/maintenance requests.

## Domain

Esper knowledge base — query and maintenance.

## Modes

`/esper` operates in two modes based on the user's request:

- **Query mode** (default): "What do I know about X?", "Find connections to Y"
- **Lint mode**: "esper lint", "check esper health", "esper maintenance"

## Tooling — `bin/esper-lint`

A deterministic Ruby CLI handles all data-gathering. **Use it instead of writing inline grep/awk/python.** Permission-allowlisted; runs without prompts.

**It is READ-ONLY — no subcommand writes to disk.** Every fix is yours to make with `Edit`.

JSON-only output on stdout. Pipe to `jq` or `python3 -c` for parsing. JSONL warnings on stderr (filter or save with `2>/tmp/warnings`).

Commands you'll use:

```
bin/esper-lint check                                  # all 7 lint checks, counts only (lint mode entrypoint)
bin/esper-lint check --detail CHECK                   # also return items[] for ONE check, by its key under "checks"
bin/esper-lint check --detail CHECK --limit N         # cap returned items (default 50); sets items_truncated
bin/esper-lint sources --orphan [--fixable]           # list orphans; --fixable narrows to ones tagged with an existing topic
bin/esper-lint sources --tag TAG                      # all sources tagged TAG
bin/esper-lint sources --topic SLUG                   # all sources linked from a topic page
bin/esper-lint topics --count-mismatch                # frontmatter source_count != actual
bin/esper-lint topics --missing-connections           # topic pages without ## Connections
bin/esper-lint tags --missing-page                    # tags >= 3 occurrences with no topic page
bin/esper-lint manifests --stale                      # manifests with null/old cursors
```

Check keys for `--detail`: `orphans`, `source_count_mismatches`, `missing_topic_candidates`, `missing_connections`, `stale_manifests`, `index_drift`, `duplicate_sources`.

Global options: `--esper-dir PATH` (default `./esper`), `--tag-threshold N` (default 3), `--stale-days N` (default 30).

Exit codes: `0` = success, `1` = `check` found findings, `2` = error (missing dir, malformed frontmatter, unknown `--detail` name, bad argument).

When you need the actual items, prefer a query subcommand (`sources` / `topics` / `tags` / `manifests`) over raising `--limit` — they filter on their own flags and return full `results`.

What the CLI does NOT do — these stay your job:
- Decide which topic an orphan belongs to (read tags, read the source's Key Takeaways, judge)
- Decide whether a missing-topic candidate should be promoted, subsumed, or ignored
- Add or update `## Connections` sections (semantic; hand-edit)
- Rewrite topic syntheses (LLM work; dispatch synthesis-refresh subagents per the prior pattern)
- Re-run integrate for stale manifests (separate skill, raw-data container only)
- Write anything at all — see Fixing below

## Memory Files

Always read on activation:
- `esper/index.md` (topic catalog — primary navigation)

Read as needed based on request:
- `esper/pages/topics/{topic}.md` — when a query matches a topic
- `esper/pages/sources/{source}.md` — when following citations
- `esper/log.md` — when checking recent activity or in lint mode

## Query Mode

When the user asks a question about their knowledge:

1. **Read `esper/index.md`** to find matching or related topics.
2. **Read matching topic pages** — check `## Current Synthesis` for the answer.
3. **Use `bin/esper-lint sources --topic SLUG`** when you want to see what's in a topic's Sources list without re-parsing the topic file.
4. **Use `bin/esper-lint sources --tag TAG`** when the query is about a tag/theme not yet promoted to a topic.
5. **Follow source links** if the user needs detail or citations.
6. **Synthesize an answer** with citations:
   - Reference sources by title and type: *(from Kindle: Deep Work, Ch. 3)*
   - Note single-source vs multi-source corroboration.
   - Flag if the topic page seems stale (many sources added since last synthesis update — `bin/esper-lint check` will tell you).
7. **Offer to file the answer** — if the query produced a valuable synthesis that doesn't already exist as a topic page, offer to create one.

**If no matching topic exists:** First try `bin/esper-lint sources --tag TAG` for the query's likely tag(s). If that returns nothing, fall back to grep on source page contents. Report what you find and whether a topic page should be created.

**Cross-system queries:** If the query relates to Cog domains (personal, work projects), mention relevant Cog context. Read from `memory/` as needed.

## Lint Mode

1. **Run `bin/esper-lint check`** and parse the JSON. This is the canonical lint pass — no inline scripting needed.

   ```bash
   bin/esper-lint check 2>/tmp/esper-warnings.log
   ```

2. **Drill into individual checks** as needed:
   - For orphan classification + suggested links: `bin/esper-lint sources --orphan --fixable`
   - For missing-topic candidates: `bin/esper-lint tags --missing-page`
   - For stale manifests: `bin/esper-lint manifests --stale`
   - For specific topic count mismatches: `bin/esper-lint topics --count-mismatch`

3. **Append findings to `esper/log.md`** in the existing format:

   ```markdown
   ## [{today's date}] esper:lint
   - Orphan source pages: {total} (stub: N, fixable: N, subthreshold: N)
   - source_count mismatches: {total}
   - Missing topic candidates: {total} (top: tag (count), tag (count), ...)
   - Missing connections: {total}
   - Stale manifests: {total} ({list of files})
   - Index drift: {total}
   - Duplicate sources: {total} ({list of topic: [slug,...]})
   - Notable warnings: {anything from stderr that needs human judgment}
   ```

4. **Present findings to the user** with recommended next actions, ranked by impact.

### Fixing

**Every fix is a hand-edit with the `Edit` tool.** The CLI finds problems; it never writes.

- **`source_count` mismatches** — read the topic page, count the unique links under `## Sources`, and edit the frontmatter `source_count` to match.
- **Duplicate `## Sources` entries** — remove the duplicate lines and keep the list alphabetically sorted.
- **Index drift** — bring the row in `esper/index.md` back in line with the topic page it describes.
- **Orphan sources** — decide the right topic (judgment), then add the link to that topic's `## Sources` and bump its `source_count` in the same edit.
- **Missing `## Connections`** — write the section; it's semantic work.
- **Missing-topic candidates** — promote to a new topic page, subsume into an existing one, or ignore. Case by case.
- **Stale syntheses** — dispatch synthesis-refresh subagents per the established pattern (see `docs/superpowers/specs/2026-05-05-esper-lint-design.md`).
- **Stale manifests** — not fixable here; they need an integrate run in the raw-data container.

Order the offers cheapest-first when presenting them: counts and duplicates, then orphan links, then topic promotion, then synthesis refreshes and `## Connections`. Only fix with user approval, re-run `bin/esper-lint check` afterward to confirm the finding cleared, and record what changed in `esper/log.md`.

### Known caveats

- **Manifest cursor `kind`**: as of esper-lint v0.2.0, manifests with `cursor.kind: opaque` (e.g. `instapaper.yaml`'s slug-based cursor) are treated as fresh by design — no age computation, no staleness flag while the value is non-null. Date-kind manifests behave as before.
- **The CLI does not check `## Connections` content** — only the section's presence. Cross-reference quality remains a judgment call.
- **`esper/` is its own git repo** (`esper/.git`). Hand-edits land there, not in the Synergy repo — commit them separately.

---

## Context

This is the query and maintenance interface for Esper. It sits alongside `/integrate` (ingestion). `/esper` is what the user invokes to search their knowledge base or check its health.

The deterministic toolkit is `bin/esper-lint` (symlinked from the user's tools project). Spec: `docs/superpowers/specs/2026-05-05-esper-lint-design.md`. Plan: `docs/superpowers/plans/2026-05-05-esper-lint.md`.

The skill lives at `.claude/commands/esper.md` alongside other Cog skills.
