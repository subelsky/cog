Use this skill to query or health-check the Esper knowledge base. Trigger if the user says "esper", "what do I know about", "search esper", "esper lint", "knowledge check", or similar query/maintenance requests.

## Domain

Esper knowledge base — query and maintenance.

## Modes

`/esper` operates in two modes based on the user's request:

- **Query mode** (default): "What do I know about X?", "Find connections to Y"
- **Lint mode**: "esper lint", "check esper health", "esper maintenance"

## Tooling — `bin/esper-lint`

A deterministic Ruby CLI handles all data-gathering and safe fixes. **Use it instead of writing inline grep/awk/python.** Permission-allowlisted; runs without prompts.

JSON-only output on stdout. Pipe to `jq` or `python3 -c` for parsing. JSONL warnings on stderr (filter or save with `2>/tmp/warnings`).

Commands you'll use:

```
bin/esper-lint check                                  # all 7 lint checks (lint mode entrypoint)
bin/esper-lint fix                                    # bump source_counts + dedup + rebuild index
                                                      # requires clean esper/ git tree
bin/esper-lint sources --orphan [--fixable]           # list orphans; --fixable narrows to ones tagged with an existing topic
bin/esper-lint sources --tag TAG                      # all sources tagged TAG
bin/esper-lint sources --topic SLUG                   # all sources linked from a topic page
bin/esper-lint topics --count-mismatch                # frontmatter source_count != actual
bin/esper-lint topics --missing-connections           # topic pages without ## Connections
bin/esper-lint tags --missing-page                    # tags >= 3 occurrences with no topic page
bin/esper-lint manifests --stale                      # manifests with null/old cursors
bin/esper-lint add-source TOPIC_SLUG SOURCE_SLUG      # add link to a topic's Sources (sort, dedup, bump count)
```

Exit codes: `0` = success, `1` = `check` found findings, `2` = error (missing dir, dirty tree on `fix`, unknown topic/source, etc.).

What the CLI does NOT do — these stay your job:
- Decide which topic an orphan belongs to (read tags, read source's Key Takeaways, judge)
- Decide whether a missing-topic candidate should be promoted, subsumed, or ignored
- Add or update `## Connections` sections (semantic; hand-edit)
- Rewrite topic syntheses (LLM work; dispatch synthesis-refresh subagents per the prior pattern)
- Re-run integrate for stale manifests (separate skill)

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

### Fixing — what the CLI handles vs. what you do

**Run `bin/esper-lint fix`** for the deterministic safe fixes:
- Bumps `source_count` in topic frontmatter to match actual unique link count
- Deduplicates `## Sources` entries (sorts alphabetically, removes duplicates)
- Rebuilds `esper/index.md` from current topic state
- Atomic; refuses to run if `git status --porcelain esper/` is non-empty
- Returns a `post_fix_check` payload showing the residual lint state

**Use `bin/esper-lint add-source TOPIC SOURCE_SLUG`** for each fixable orphan you decide should be linked. Idempotent (returns `was_already_present: true` if already there).

**Hand-edit when:**
- Adding/updating `## Connections` sections (judgment-driven)
- Promoting a missing-topic candidate to a real topic page (write the file, then `bin/esper-lint fix` rebuilds the index)
- Subsuming a candidate into an existing topic (no edit needed; just note in log.md)
- Refreshing stale syntheses (dispatch synthesis-refresh subagents per the established pattern — see `docs/superpowers/specs/2026-05-05-esper-lint-design.md` for context)

### Auto-fix protocol

After presenting findings, offer specific actions in this order (cheapest first):

1. **"Run `bin/esper-lint fix`?"** — clears all source_count mismatches, duplicate Sources entries, and index drift in one shot. Always offer first if any of these checks have findings.
2. **"Link the N fixable orphans?"** — call `bin/esper-lint add-source` per source × matching topic. Confirm the topic for each before linking.
3. **"Promote/subsume the missing-topic candidates?"** — case-by-case judgment.
4. **"Refresh stale syntheses on the top-N high-volume topics?"** — dispatch synthesis-refresh subagents.
5. **"Add `## Connections` to the N topics missing one?"** — hand-edit per topic.

Only fix with user approval. Always report what was fixed in `esper/log.md`.

### Known caveats

- **`fix` requires the esper directory to be in a git repo** with a clean working tree. Esper has its own git repo at `esper/.git`. Always run `cd esper && git status` before `fix`. If dirty, ask the user whether to commit/stash first.
- **The `instapaper.yaml` manifest uses a slug-based cursor** (e.g. `last_processed: zakelfassi.com_2cfea35833e8`) instead of a date. The CLI flags this as `unparseable_cursor_date` and reports the manifest as stale. This is a known mismatch between the spec (date cursors) and one manifest format (filesystem-walk cursor). Note in the lint report but don't treat as actionable.
- **The CLI does not check `## Connections` content** — only the section's presence. Cross-reference quality remains a judgment call.

---

## Context

This is the query and maintenance interface for Esper. It sits alongside `/integrate` (ingestion). `/esper` is what the user invokes to search their knowledge base or check its health.

The deterministic toolkit is `bin/esper-lint` (symlinked from the user's tools project). Spec: `docs/superpowers/specs/2026-05-05-esper-lint-design.md`. Plan: `docs/superpowers/plans/2026-05-05-esper-lint.md`.

The skill lives at `.claude/commands/esper.md` alongside other Cog skills.
