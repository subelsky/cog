Use this skill to ingest new sources into Esper. Trigger if the user says "integrate", "ingest", "process sources", "feed esper", or similar ingestion requests.

## SECURITY GATE — MANDATORY

**Before ANY source processing, verify the environment:**

Run this check FIRST:

```bash
echo $DEVCONTAINER
```

If the output is NOT `true`, STOP IMMEDIATELY and display:

> **BLOCKED: `/integrate` extract phase requires `DEVCONTAINER=true`.**
> The extract phase processes untrusted content (emails, web articles) and must run inside a sandboxed devcontainer. This is a security requirement, not a suggestion.

The integrate phase (processing `_staging/` content) may run outside a devcontainer since it only reads LLM-authored summaries.

## Domain

Esper knowledge base — source ingestion pipeline.

## Tool Restrictions

This skill ONLY uses:
- `Read` — source files + existing Esper pages
- `Write` / `Edit` — ONLY paths under `esper/`
- `Glob` / `Grep` — ONLY within `esper/`

DO NOT use:
- `Bash` (except for the DEVCONTAINER check above)
- `WebFetch` / `WebSearch`
- Any writes outside `esper/`

## Workflow

### Phase 0: Preflight

1. Run the DEVCONTAINER check (see Security Gate above)
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

7. **Advance cursors** — update each source manifest's cursor to reflect what was processed
8. **Clean staging** — delete all files in `esper/_staging/`

### Phase 3: Report

Summarize what happened:
- How many sources processed, by type
- New source pages created
- New topics that emerged
- Existing topics that were updated
- Any items that couldn't be processed (and why)

## Format-Specific Parsing Notes

**JSONL (Claude Code transcripts):** Each line is a JSON object. User messages have `type: "user"` — when `message.content` is a string, it's user input. When it's an array, it's tool results (skip for summary, but note tools used). Assistant text is in `type: "assistant"` messages. Summarize the session's goals, decisions made, code written, and outcomes.

**Clippings (Kindle):** `My Clippings.txt` uses `==========` as delimiter between highlights. Each highlight has a book title line, location/date line, blank line, then highlight text. Group by book title — each book is one source page.

**Markdown (Instapaper):** Already structured. Extract title from first `# ` heading or filename. Summarize key arguments and notable passages.

**EML (Email):** Parse headers for From, To, Subject, Date. Group by thread (Subject line). Summarize the thread's key points, decisions, and action items.

**conversation-json (Claude Chat):** JSON export of chat conversations. Each conversation has messages array. Summarize goals, key exchanges, decisions, and insights.

For formats not yet supported, report the items as skipped and note the format in the log.
