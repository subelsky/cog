# Esper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold Esper's directory structure, create the `/integrate` and `/ember` skills, and add Esper awareness to existing Cog pipeline skills.

**Architecture:** Esper is a markdown knowledge base at `esper/` with source manifests (YAML), source pages, emergent topic pages, a two-tier index, and an append-only log. Two new skills (`/integrate`, `/ember`) manage it. Three existing Cog skills gain Esper awareness sections.

**Tech Stack:** Markdown, YAML, Claude Code skills (`.claude/commands/*.md`), subagents for parallel extract.

**Spec:** `docs/superpowers/specs/2026-04-11-esper-design.md`

---

### Task 1: Scaffold Esper directory structure

**Files:**
- Create: `esper/index.md`
- Create: `esper/log.md`
- Create: `esper/sources/.gitkeep`
- Create: `esper/raw/.gitkeep`
- Create: `esper/pages/sources/.gitkeep`
- Create: `esper/pages/topics/.gitkeep`
- Create: `esper/_staging/.gitkeep`

- [ ] **Step 1: Create the directory tree**

Create `esper/` with all subdirectories. Use `.gitkeep` files in empty directories so git tracks them.

- [ ] **Step 2: Create `esper/index.md`**

```markdown
<!-- L0: Two-tier topic index — entry point for all Esper queries -->
# Esper Index

## Topics

| Topic | Sources | Last Updated | Summary |
|-------|---------|--------------|---------|

*No topics yet. Topics emerge automatically when 3+ sources share a theme.*
```

- [ ] **Step 3: Create `esper/log.md`**

```markdown
<!-- L0: Chronological record of all Esper operations -->
# Esper Log

*No operations yet. Run `/integrate` to process your first sources.*
```

- [ ] **Step 4: Commit**

```bash
git add esper/
git commit -m "feat(esper): scaffold directory structure with index and log"
```

---

### Task 2: Create example source manifests

**Files:**
- Create: `esper/sources/claude-code.yml`
- Create: `esper/sources/claude-chat.yml`
- Create: `esper/sources/kindle.yml`
- Create: `esper/sources/instapaper.yml`
- Create: `esper/sources/email.yml`
- Create: `esper/sources/things3.yml`
- Create: `esper/sources/git-repos.yml`

These are starter manifests. The user will customize mount paths and cursors for their actual setup.

- [ ] **Step 1: Create `esper/sources/claude-code.yml`**

```yaml
name: Claude Code Transcripts
type: filesystem
mount: /sources/claude-code
format: jsonl
cursor:
  last_processed: null
  files_processed: []
notes: |
  JSONL session files copied from other devcontainers.
  Same format as ~/.claude/projects/ session files.
  Each session becomes one source page.
```

- [ ] **Step 2: Create `esper/sources/claude-chat.yml`**

```yaml
name: Claude Chat Transcripts
type: api
api: claude-conversations
format: conversation-json
cursor:
  last_sync: null
  last_conversation_id: null
notes: |
  Primary: Anthropic conversations API (if available).
  Fallback: periodic JSON export dropped into raw/claude-chat/.
  Each conversation becomes one source page.
```

- [ ] **Step 3: Create `esper/sources/kindle.yml`**

```yaml
name: Kindle Highlights
type: filesystem
mount: /sources/kindle
format: clippings
cursor:
  last_processed: null
  files_processed: []
```

- [ ] **Step 4: Create `esper/sources/instapaper.yml`**

```yaml
name: Instapaper Articles
type: filesystem
mount: /sources/instapaper
format: markdown
cursor:
  last_processed: null
  files_processed: []
```

- [ ] **Step 5: Create `esper/sources/email.yml`**

```yaml
name: Saved Emails
type: filesystem
mount: /sources/email
format: eml
cursor:
  last_processed: null
  files_processed: []
```

- [ ] **Step 6: Create `esper/sources/things3.yml`**

```yaml
name: Things 3
type: mcp
server: things3
cursor:
  last_sync: null
```

- [ ] **Step 7: Create `esper/sources/git-repos.yml`**

```yaml
name: Code History
type: git
repos: []
cursor:
  last_commit_per_repo: {}
notes: |
  Add repos as needed. Each entry:
    - path: /sources/repos/project-name
      include: ["README.md", "docs/**"]
```

- [ ] **Step 8: Commit**

```bash
git add esper/sources/
git commit -m "feat(esper): add starter source manifests"
```

---

### Task 3: Create the `/integrate` skill

**Files:**
- Create: `.claude/commands/integrate.md`

This is the core new skill. It orchestrates the two-phase ingest pipeline with the DEVCONTAINER environment gate and subagent dispatch for parallel extraction.

- [ ] **Step 1: Create `.claude/commands/integrate.md`**

```markdown
Use this skill to ingest new sources into Esper. Trigger if the user says "integrate", "ingest", "process sources", "feed esper", or similar ingestion requests.

## SECURITY GATE — MANDATORY

**Before ANY source processing, verify the environment:**

Run this check FIRST:
\`\`\`bash
echo $DEVCONTAINER
\`\`\`

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

\`\`\`markdown
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
\`\`\`

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

\`\`\`markdown
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
\`\`\`

   - If a topic page already exists and new sources reference it, update it:
     - Add new source links to `## Sources`
     - Rewrite `## Current Synthesis` to incorporate new sources
     - Update `source_count` in frontmatter
5. **Update `esper/index.md`** — rebuild the topics table from all topic pages
6. **Append to `esper/log.md`:**

\`\`\`markdown
## [{today's date}] integrate | {summary}
- Processed: {count} new items across {source types}
- Created: {n} source pages ({list})
- Created: {n} new topics ({list})
- Updated: {n} existing topics ({list})
\`\`\`

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
```

- [ ] **Step 2: Verify the skill loads**

Check that Claude Code recognizes the new skill by confirming the file is valid markdown with no syntax errors. Read it back and verify the structure is complete.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/integrate.md
git commit -m "feat(esper): create /integrate skill with two-phase pipeline and DEVCONTAINER gate"
```

---

### Task 4: Create the `/ember` skill

**Files:**
- Create: `.claude/commands/ember.md`

- [ ] **Step 1: Create `.claude/commands/ember.md`**

```markdown
Use this skill to query or health-check the Esper knowledge base. Trigger if the user says "ember", "what do I know about", "search esper", "esper lint", "knowledge check", or similar query/maintenance requests.

## Domain

Esper knowledge base — query and maintenance.

## Modes

`/ember` operates in two modes based on the user's request:

- **Query mode** (default): "What do I know about X?", "Find connections to Y"
- **Lint mode**: "ember lint", "check esper health", "esper maintenance"

## Memory Files

Always read on activation:
- `esper/index.md` (topic catalog — the primary navigation tool)

Read as needed based on query:
- `esper/pages/topics/{topic}.md` — when a query matches a topic
- `esper/pages/sources/{source}.md` — when following citations from topics
- `esper/log.md` — when checking recent activity or in lint mode
- Source manifests in `esper/sources/` — in lint mode for coverage checks

## Query Mode

When the user asks a question about their knowledge:

1. **Read `esper/index.md`** to find matching or related topics
2. **Read matching topic pages** — check `## Current Synthesis` for the answer
3. **Follow source links** if the user needs more detail or citations
4. **Synthesize an answer** with citations back to specific source pages:
   - Reference sources by title and type: *(from Kindle: Deep Work, Ch. 3)*
   - Note when information comes from a single source vs. multiple corroborating sources
   - Flag if the topic page seems stale (many sources added since last synthesis update)
5. **Offer to file the answer** — if the query produced a valuable synthesis that doesn't already exist as a topic page, offer to create one. This is how explorations compound back into the knowledge base.

**If no matching topic exists:** Search source pages directly via Grep for the query terms. Report what you find and whether a topic page should be created.

**Cross-system queries:** If the query relates to Cog domains (personal, work projects), mention relevant Cog context. For example, "What do I know about leadership?" might reference both Esper topic pages AND Cog entities/observations. Read from `memory/` as needed.

## Lint Mode

Health-check the Esper knowledge base. Read broadly, report findings.

### Checks to run:

1. **Orphan source pages** — source pages in `esper/pages/sources/` that aren't linked from any topic page.
   - Glob all source pages, grep each filename across topic pages
   - Report orphans and suggest which topics they might belong to

2. **Stale topic syntheses** — topic pages where `source_count` in frontmatter doesn't match the actual number of source links in `## Sources`.
   - Read each topic page, count source links, compare to frontmatter
   - Flag mismatches — the synthesis needs rewriting

3. **Missing topics** — themes appearing in 3+ source pages that lack a topic page.
   - Read all source page frontmatter `topics:` fields
   - Count tag frequency across all source pages
   - Report any tag with 3+ occurrences that has no matching topic page

4. **Missing cross-references** — topic pages that discuss related concepts but don't link to each other.
   - Read all topic pages, check if `## Connections` sections reference related topics
   - Suggest missing connections

5. **Source coverage gaps** — source manifests where `cursor.last_processed` or `cursor.last_sync` is null or older than 30 days.
   - Read all manifests in `esper/sources/`
   - Report inactive sources

6. **Index accuracy** — verify `esper/index.md` matches the actual topic pages on disk.
   - Glob `esper/pages/topics/*.md`, compare to index entries
   - Report missing or extra entries

### Lint report format:

Append findings to `esper/log.md`:

\`\`\`markdown
## [{today's date}] ember:lint
- Orphan source pages: {count} ({list or "none"})
- Stale topics: {count} ({list or "none"})
- Missing topics: {count} suggestions ({list or "none"})
- Missing cross-refs: {count} suggestions ({list or "none"})
- Source coverage gaps: {count} ({list or "none"})
- Index accuracy: {ok or list of issues}
\`\`\`

Then present the findings to the user with recommended actions.

### Auto-fix options:

After reporting, offer to fix issues:
- "Create missing topic pages?" — for themes at 3+ sources
- "Update stale syntheses?" — rewrite Current Synthesis sections
- "Rebuild index?" — regenerate index.md from actual topic pages
- "Link orphan source pages?" — add them to relevant topics

Only fix with user approval. Report what was fixed in the log.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/ember.md
git commit -m "feat(esper): create /ember skill for query and lint"
```

---

### Task 5: Add Esper awareness to `/housekeeping`

**Files:**
- Modify: `.claude/commands/housekeeping.md`

Read the full current content of housekeeping.md, then add an Esper section.

- [ ] **Step 1: Read the full housekeeping skill**

Read `.claude/commands/housekeeping.md` in its entirety to understand the current structure and find the right place to add the Esper section.

- [ ] **Step 2: Add Esper awareness section**

Add a new section at the end of the housekeeping skill (before any closing content), titled `## 7. Esper Coordination` (adjust number to follow the existing section numbering):

```markdown
## N. Esper Coordination

If `esper/index.md` exists, perform these additional checks:

**Cross-system link check:**
- Grep all Cog observation files for topic names that exist in Esper's index
- If a Cog observation references a topic with 3+ mentions but no `[[esper/topics/...]]` link, flag it
- Suggest adding wiki-links from Cog observations to relevant Esper topic pages

**Esper link health:**
- Verify all `[[esper/...]]` links in Cog files point to files that exist
- Verify all `[[personal/...]]` or `[[work/...]]` links in Esper files point to files that exist
- Report broken links

**Esper in briefing bridge:**
- When writing `cog-meta/briefing-bridge.md`, include a section noting:
  - Number of Esper source pages and topic pages
  - Most recently updated topics
  - Any lint issues found (if available from recent `esper/log.md` entries)
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/housekeeping.md
git commit -m "feat(esper): add Esper awareness to /housekeeping"
```

---

### Task 6: Add Esper awareness to `/reflect`

**Files:**
- Modify: `.claude/commands/reflect.md`

- [ ] **Step 1: Read the full reflect skill**

Read `.claude/commands/reflect.md` in its entirety.

- [ ] **Step 2: Add Esper awareness section**

Add a section to the reflect skill's process (after session transcript mining, before the closing steps):

```markdown
## N. Esper Cross-Reference

If `esper/index.md` exists, check for connections between session content and Esper:

**Session-to-Esper mapping:**
- When mining session transcripts, note topics discussed extensively
- Check if those topics exist as Esper topic pages
- If a session discussed a topic at length but Esper has no page for it, note in self-observations: "Session discussed {topic} extensively — Esper has no topic page. Consider adding sources."

**Source suggestions:**
- If a session referenced external content (articles, books, talks) that aren't in Esper, note: "Session referenced {source} — not yet in Esper. Suggest ingesting."
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/reflect.md
git commit -m "feat(esper): add Esper awareness to /reflect"
```

---

### Task 7: Add Esper awareness to `/foresight`

**Files:**
- Modify: `.claude/commands/foresight.md`

- [ ] **Step 1: Read the full foresight skill**

Read `.claude/commands/foresight.md` in its entirety.

- [ ] **Step 2: Add Esper to the data sources**

In the Memory Files section, add Esper sources:

```markdown
- `esper/index.md` (Esper topic catalog — what has been read/learned)
- Recent entries in `esper/log.md` (what was recently ingested)
```

Add to the Cross-Domain Convergence Scan or equivalent process section:

```markdown
**Esper convergence:**
- Check if any Esper topics directly relate to active Cog action items or project goals
- Look for patterns: "You've been reading about X (Esper) while working on Y (Cog) — there may be a connection"
- Surface Esper topics that have grown recently (many new sources) as potential areas of emerging interest
- Note if Esper topics contradict or complicate Cog assumptions
```

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/foresight.md
git commit -m "feat(esper): add Esper awareness to /foresight"
```

---

### Task 8: Update CLAUDE.md with Esper reference

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read the relevant sections of CLAUDE.md**

Read the Domain Routing & Skills table, the Memory System directory map, and the File Edit Patterns table.

- [ ] **Step 2: Add Esper to the skill routing table**

Add these rows to the skill table in CLAUDE.md:

```markdown
| `/integrate`         | Esper                                     | "integrate", "ingest", "process sources", "feed esper"            |
| `/ember`             | Esper                                     | "ember", "what do I know about", "esper lint", "knowledge check"  |
```

- [ ] **Step 3: Add Esper to the directory map**

Add the Esper directory tree after the `memory/` tree:

```markdown
### Esper Directory Map

Esper is the knowledge base — compiled from external sources. See `docs/superpowers/specs/2026-04-11-esper-design.md` for full spec.

\`\`\`
esper/
  index.md                         # Two-tier topic index (topics only)
  log.md                           # Append-only operation log
  sources/                         # Source manifests (one YAML per type)
  raw/                             # Immutable source files
  pages/
    sources/                       # One page per logical source unit
    topics/                        # Emergent topic pages (3+ sources)
  _staging/                        # Extract phase output (sanitization buffer)
\`\`\`
```

- [ ] **Step 4: Add Esper file edit patterns**

Add to the File Edit Patterns table:

```markdown
| `esper/index.md`                | Rebuild from topic pages on each integrate run |
| `esper/log.md`                  | Append only                                    |
| `esper/pages/sources/*.md`      | Create on ingest, rarely update                |
| `esper/pages/topics/*.md`       | Current Synthesis: rewrite. Sources: append    |
| `esper/sources/*.yml`           | Cursors updated by /integrate                  |
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add Esper system to CLAUDE.md skill routing and directory map"
```

---

### Task 9: Update user guide and commit docs

**Files:**
- Verify: `docs/synergy-user-guide.md` (already written, verify it's consistent with final skill implementations)
- Verify: `docs/superpowers/specs/2026-04-11-esper-design.md`

- [ ] **Step 1: Re-read the user guide**

Read `docs/synergy-user-guide.md` and verify all skill names, descriptions, and workflows match what was actually implemented in Tasks 3-4.

- [ ] **Step 2: Fix any inconsistencies**

If the user guide references behaviors not in the actual skills, or misses behaviors that are, update it.

- [ ] **Step 3: Commit all docs**

```bash
git add docs/
git commit -m "docs: finalize Esper spec and Synergy user guide"
```
