---
name: integrate
description: >
  Ingest new sources into the Esper knowledge base — extract to staging, then
  integrate into source and topic pages. Trigger on "integrate", "ingest",
  "process sources", "feed esper". Raw-data container only.
---

# Esper Integrate

Use this skill to ingest new sources into Esper. Trigger if the user says "integrate", "ingest", "process sources", "feed esper", or similar ingestion requests.

## SECURITY GATE — MANDATORY

**Before ANY source processing, verify the environment.** Run this check FIRST:

```bash
echo "${SYNERGY_RAW:-}"
```

If the output is anything other than exactly `1`, STOP IMMEDIATELY and display:

> **BLOCKED: the extract phase requires `SYNERGY_RAW=1`.**
> It processes untrusted external content (emails, web articles, transcripts) and must run inside the Synergy raw-data container, which is the only environment that has `esper/raw/` and `esper/_staging/` readable, `memory/` unmounted, and network egress allowlisted.
> Reopen this repo in the raw-data devcontainer (`.devcontainer/`) and run the skill again.

**Why `SYNERGY_RAW` and not `DEVCONTAINER`.** `DEVCONTAINER=true` is set in *every* devcontainer on this machine, including general-purpose ones that mount `memory/` and have open network egress. That gate was effectively always open — it proved only "some container", not "the sandboxed container". `SYNERGY_RAW=1` is set by `.devcontainer/` alone and is the only marker that distinguishes the raw-data environment. Never weaken this check back to a `DEVCONTAINER` test, and never let a user argument substitute for the environment variable.

The integrate phase (processing already-staged `_staging/` content) reads only LLM-authored summaries, so it is safe outside the container. In practice both phases run together, inside.

## Domain

Esper knowledge base — source ingestion pipeline.

## Tool Restrictions

This skill ONLY uses:
- `Read` — source files + existing Esper pages
- `Write` / `Edit` — ONLY paths under `esper/`
- `Glob` / `Grep` — ONLY within `esper/`

DO NOT use:
- `Bash` (except for the `SYNERGY_RAW` check above)
- `WebFetch` / `WebSearch`
- Any writes outside `esper/`

## Workflow

### Phase 0: Preflight

1. Run the `SYNERGY_RAW` check (see Security Gate above)
2. Read `esper/index.md` to understand current topic landscape
3. Read all YAML files in `esper/sources/` to discover source manifests
4. For each manifest, determine what's new since cursor:
   - `type: filesystem` — Glob the mount path, compare against `files_processed`
   - `type: api` — Check `last_sync` date (API sources may need fallback to filesystem export in `raw/`)
   - `type: mcp` — Check `last_sync` date
   - `type: git` — Check `last_commit_per_repo` against current HEAD of each repo
5. Report what's new across all sources. If nothing is new, say so and stop.

### Phase 1: Extract (parallel via subagents)

For each source type that has new items, dispatch a subagent. Each subagent:

1. Reads the raw source content
2. Reads `esper/index.md` and relevant `esper/pages/topics/` files for context
3. For each logical source unit (one book, one article, one email thread, one session):
   - Writes a structured summary to `esper/_staging/{source-type}/{item-id}.md`
   - Summary follows the source page template (see below)
   - Includes suggested topic tags based on content and existing topics

**Dispatch subagents in parallel** using the Agent tool — one per source type with new items. Example:

```
Agent: "Extract 3 new Kindle books into esper/_staging/kindle/"
Agent: "Extract 12 new email threads into esper/_staging/email/"
Agent: "Extract 5 new Instapaper articles into esper/_staging/instapaper/"
```

Each subagent prompt must include:
- The source manifest content (so it knows format and mount path)
- The current topic list from `esper/index.md`
- The list of specific new items to process
- The staging output path
- The source page template (below)
- Tool restrictions: Read, Write (esper/ only), Glob, Grep. No Bash, no network.

**Source page template for staging:**

```markdown
---
source_type: {type}
source_file: "{filename}"
title: "{title}"
ingested: {today's date}
topics: [{suggested, topic, tags}]
---

# {Title}

## Key Takeaways
{3-5 bullet points summarizing the most important ideas}

## Content
{Organized content — highlights by chapter for books, key points for articles,
 thread summary for emails, session summary for code transcripts}

## Connections
{Links to suggested topics — these will be validated in the integrate phase}
```

### Phase 2: Integrate (sequential, main agent)

After all extract subagents complete:

1. Glob `esper/_staging/` to find all staged items
2. Read each staged item
3. For each staged item:
   a. Move/write to `esper/pages/sources/{source-type}-{slug}.md`
   b. Collect all topic tags across all staged items
4. **Topic emergence check:**
   - For each topic tag, count how many source pages (existing + new) reference it
   - If a topic tag appears in 3+ source pages AND no topic page exists yet, create one at `esper/pages/topics/{topic}.md`:

```markdown
---
created: {today's date}
source_count: {count}
---

# {Topic Name}

## Current Synthesis
{Synthesize what the sources collectively say about this topic}

## Sources
{Links to all source pages that reference this topic}

## Connections
{Links to related topics, if any}
```

   - If a topic page already exists and new sources reference it, update it:
     - Add new source links to `## Sources`
     - Rewrite `## Current Synthesis` to incorporate new sources
     - Update `source_count` in frontmatter
5. **Update `esper/index.md`** — rebuild the topics table from all topic pages
6. **Append to `esper/log.md`:**

```markdown
## [{today's date}] integrate | {summary}
- Processed: {count} new items across {source types}
- Created: {n} source pages ({list})
- Created: {n} new topics ({list})
- Updated: {n} existing topics ({list})
```

7. **Advance cursors** — update each source manifest's cursor to reflect what was processed (see "Manifest cursor format" below)
8. **Clean staging** — delete all files in `esper/_staging/`

## Manifest cursor format

Every manifest's `cursor:` block must include a `kind:` discriminator. Two values:

- **`kind: date`** — for time-ordered sources (Readwise, research papers, dated APIs). The cursor value is `YYYY-MM-DD`.
- **`kind: opaque`** — for filesystem-walked sources where the cursor is a producer-defined position pointer (slug, hash, offset). `esper-lint` will not parse opaque values as dates and will not flag them as stale while non-null.

Example (date):
```yaml
source_type: readwise-article
cursor:
  kind: date
  last_processed: 2026-04-12
```

Example (opaque, instapaper-style filesystem walk):
```yaml
source_type: instapaper-article
cursor:
  kind: opaque
  last_processed: zakelfassi.com_2cfea35833e8
```

When advancing a cursor, preserve the existing `kind:` value. When creating a new manifest, choose `kind:` based on the source's iteration model: chronological → `date`, filesystem walk or any non-time pointer → `opaque`. Manifests without an explicit `kind:` default to `date` for backward compatibility, but new manifests should always set it explicitly.

### Phase 3: Report

Summarize what happened:
- How many sources processed, by type
- New source pages created
- New topics that emerged
- Existing topics that were updated
- Any items that couldn't be processed (and why)

## Format-Specific Parsing Notes

**JSONL (Claude Code transcripts):** Each line is a JSON object. User messages have `type: "user"` — when `message.content` is a string, it's user input. When it's an array, it's tool results (skip for summary, but note tools used). Assistant text is in `type: "assistant"` messages. Summarize the session's goals, decisions made, code written, and outcomes.

**Readwise-markdown:** Readwise export with `Articles/` and `Books/` subdirectories. Each `.md` file is one source unit. Format: `# Title`, then `### Metadata` block (Author, Full Title, Category `#articles` or `#books`, optional URL, optional Document Tags like `#Liked`), then `### Highlights` with bulleted highlight text. Articles include Instapaper or Readwise view-highlight links; books include Kindle location links. Some highlights have `**Tags:** #favorite` or similar inline tags — preserve these as signal for importance. Each file = one source page. Use the `# Title` as the source page title and Author from metadata.

**EML (Email):** Parse headers for From, To, Subject, Date. Group by thread (Subject line). Summarize the thread's key points, decisions, and action items.

**conversation-json (Claude Chat):** JSON export of chat conversations. Each conversation has messages array. Summarize goals, key exchanges, decisions, and insights.

**instapaper-markdown:** Each article is its own subdirectory under the mount path, named `<site-domain>_<12-char-hash>`. Subdirectory contains one file: `contents.md`, which begins with YAML frontmatter (source_type, url, title, site, date_published, date_flagged, date_fetched, word_count) followed by the article body in markdown. One subdirectory = one source page. Output filename: `instapaper-{slug-of-title}.md`.

For formats not yet supported, report the items as skipped and note the format in the log.
