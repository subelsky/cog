# Esper — Synergy's Knowledge Base

A persistent, compounding knowledge base maintained by Synergy. Raw sources go in, structured interlinked markdown pages come out. Named after the image enhancement machine in Blade Runner — it takes raw inputs and reveals what's hidden.

## Relationship to Cog

Esper and Cog are sibling systems with shared pipeline plumbing.

- **Cog** (`memory/`) — cognitive state: who you are, what you're doing, what you're thinking
- **Esper** (`esper/`) — compiled knowledge: what you've read, learned, collected

They cross-reference via wiki-links (`[[esper/topics/leadership]]` from Cog, `[[personal/entities#Someone]]` from Esper). Cog pipeline skills (`/housekeeping`, `/reflect`, `/foresight`) are aware of Esper and maintain coordination.

## Directory Structure

```
esper/
  index.md              # Topic-level catalog (two-tier: topics only)
  log.md                # Chronological append-only record of operations
  sources/              # Source manifests (one YAML per source type)
    kindle.yml
    instapaper.yml
    email.yml
    things3.yml
    git-repos.yml
    claude-chat.yml
    claude-code.yml
  raw/                  # Immutable source files (mounted or copied)
    kindle/
    instapaper/
    email/
    ...
  pages/
    sources/            # One page per logical source unit
    topics/             # Emergent — created when 3+ sources share a theme
  _staging/             # Temporary extract output (sanitization buffer)
```

## Source Manifests

Each source type gets a YAML manifest in `esper/sources/` defining access, format, and cursor state.

### Filesystem sources

```yaml
# esper/sources/kindle.yml
name: Kindle Highlights
type: filesystem
mount: /sources/kindle
format: clippings
cursor:
  last_processed: "2026-04-10"
  files_processed:
    - "My Clippings.txt:sha256:abc123"
```

### MCP sources

```yaml
# esper/sources/things3.yml
name: Things 3
type: mcp
server: things3
cursor:
  last_sync: "2026-04-10"
```

### Git sources

```yaml
# esper/sources/git-repos.yml
name: Code History
type: git
repos:
  - path: /sources/repos/project-alpha
    include: ["README.md", "docs/**"]
  - path: /sources/repos/project-beta
    include: ["README.md", "CHANGELOG.md"]
cursor:
  last_commit_per_repo:
    project-alpha: "abc1234"
    project-beta: "def5678"
```

### Claude conversation sources

```yaml
# esper/sources/claude-chat.yml
name: Claude Chat Transcripts
type: api
api: claude-conversations
format: conversation-json
cursor:
  last_sync: "2026-04-10"
  last_conversation_id: "conv_abc123"
notes: |
  Primary: Anthropic conversations API (if available).
  Fallback: periodic JSON export dropped into raw/claude-chat/.
  Each conversation becomes one source page.
```

```yaml
# esper/sources/claude-code.yml
name: Claude Code Transcripts
type: filesystem
mount: /sources/claude-code
format: jsonl
cursor:
  last_processed: "2026-04-10"
  files_processed: []
notes: |
  JSONL session files copied from other devcontainers.
  Same format as ~/.claude/projects/ session files.
  Each session becomes one source page.
  These transcripts feed Esper directly — Cog's /reflect
  only processes sessions from the current project.
  Esper captures cross-project knowledge.
```

### Adding new source types

Adding a source = creating a new manifest + ensuring the skill has parser logic for the format. Manifests are self-describing so `/integrate` can handle new sources without restructuring.

## Page Structure

### Source pages (`pages/sources/`)

One page per logical source unit: one book, one article, one email thread, one project.

```markdown
---
source_type: kindle
source_file: "My Clippings.txt"
title: "Deep Work by Cal Newport"
ingested: 2026-04-11
topics: [focus, productivity, knowledge-work]
---

# Deep Work — Cal Newport

## Key Takeaways
...

## Highlights by Chapter
### Chapter 1: ...
...

## Connections
- [[esper/topics/focus]]
- [[esper/topics/productivity]]
```

### Topic pages (`pages/topics/`)

Emergent — created by `/integrate` when a theme appears in 3+ source pages.

```markdown
---
created: 2026-04-11
source_count: 5
---

# Leadership

## Current Synthesis
What the sources collectively say about this topic. Rewritten freely as new sources arrive.

## Sources
- [[esper/pages/sources/kindle-deep-work]] — highlights on deep leadership vs. shallow management
- [[esper/pages/sources/email-2026-03-investor-thread]] — leadership framing in investor comms
- [[esper/pages/sources/instapaper-quiet-leadership]] — article on introverted leadership styles

## Connections
- [[esper/topics/management]]
- [[personal/entities#TrayVerify team]]
```

### Index (`index.md`)

Two-tier: lists topic pages only. Source pages are discoverable through topics.

```markdown
# Esper Index

## Topics

| Topic | Sources | Last Updated | Summary |
|-------|---------|-------------|---------|
| [Leadership](pages/topics/leadership.md) | 5 | 2026-04-11 | Synthesis of leadership styles from reading and experience |
| [Focus](pages/topics/focus.md) | 3 | 2026-04-11 | Deep work, attention management, distraction |
```

### Log (`log.md`)

Append-only, parseable with unix tools.

```markdown
# Esper Log

## [2026-04-11] integrate | Kindle Highlights
- Processed: My Clippings.txt (47 new highlights)
- Created: 3 source pages (Deep Work, Atomic Habits, Staff Engineer)
- Created: 1 new topic (focus)
- Updated: 2 topics (leadership, productivity)

## [2026-04-11] ember:lint
- 2 orphan source pages (no topic links)
- 1 suggested topic: "hiring" (appears in 3 sources)
```

## Skills

### `/integrate` — Source ingestion

Processes new sources into Esper. Designed to run offline in a devcontainer.

**Environment gate:** The extract phase MUST check `ENV DEVCONTAINER=true` before processing any raw source content. If the variable is not set, `/integrate` refuses to run the extract phase and exits with an error. This prevents accidental execution of untrusted content processing outside the sandboxed environment. The integrate phase (reading from `_staging/`) may run anywhere since it only touches LLM-authored content.

**Workflow:**

1. **Preflight**: Verify `DEVCONTAINER=true` environment variable. Abort if not set.
2. Read all source manifests from `esper/sources/`
3. For each source, determine what's new since cursor
4. **Extract phase** (per source item) — parallelizable via subagents:
   - Read the raw source content
   - Read existing Esper pages for context (topics, index)
   - Write a structured summary to `esper/_staging/{source-type}/{item-id}.md`
   - This is the dangerous step — LLM is reading untrusted content
5. **Integrate phase** (per staged item) — sequential, single agent:
   - Read from `_staging/` (LLM-authored, not raw)
   - Create/update source page in `pages/sources/`
   - Update relevant topic pages or create new ones (3+ source threshold)
   - Update `index.md`
   - Append to `log.md`
6. Advance cursors in source manifests
7. Clean `_staging/`

### Subagent architecture

`/integrate` uses subagents for parallelism during the extract phase. Each source manifest can be processed independently — Kindle highlights don't depend on email processing.

```
Main agent (/integrate)
  ├── Preflight check (DEVCONTAINER=true)
  ├── Read manifests, determine new items
  ├── Dispatch extract subagents (parallel):
  │     ├── Agent: kindle (extract 3 new books)
  │     ├── Agent: email (extract 12 new threads)
  │     ├── Agent: instapaper (extract 5 new articles)
  │     └── Agent: claude-code (extract 8 new sessions)
  ├── Integrate phase (sequential, main agent):
  │     └── Process all _staging/ items, update pages/topics/index/log
  └── Advance cursors, clean staging
```

**Why extract is parallel, integrate is sequential:** Extract subagents only write to isolated staging paths (`_staging/kindle/`, `_staging/email/`, etc.) — no conflicts. The integrate phase must be sequential because it updates shared state: topic pages, index.md, and the 3+ source threshold for emergent topics depends on seeing all staged items together.

**Subagent permissions:** Extract subagents inherit the same restricted tool set as the main `/integrate` skill — Read, Write (esper/ only), Glob, Grep. No Bash, no network, no writes outside esper/.

### `/ember` — Query and lint

**Query mode:** "What do I know about X?"
1. Read `index.md` to find relevant topic pages
2. Read topic pages, follow links to source pages as needed
3. Synthesize answer with citations

**Lint mode:** Health-check the knowledge base.
- Orphan source pages (no topic links)
- Topics with stale synthesis (new sources added since last rewrite)
- Themes appearing in 3+ sources that lack a topic page
- Missing cross-references between related topics
- Source coverage gaps (manifests with no recent ingests)

## Security Model

`/integrate` processes semi-trusted content (email, web articles) that may contain prompt injection. Three defense layers:

### Layer 1: Environment restriction (devcontainer)

`/integrate`'s extract phase requires `DEVCONTAINER=true` environment variable — hard gate, no override. The skill checks this before touching any raw source content.

The devcontainer provides:
- Read-only mounts to source directories
- Write access only to `esper/` — not `memory/`, not `~/.claude/`, not home
- No network access
- No access to credentials, SSH keys, or secrets

### Layer 2: Permission scoping (skill-level)

`/integrate` only uses:
- `Read` — sources + existing Esper pages
- `Write` / `Edit` — only to paths under `esper/`
- `Glob` / `Grep` — only within `esper/`

Explicitly excluded from extract subagents:
- `Bash` — no shell command execution (except DEVCONTAINER check by the main orchestrator)
- `WebFetch` / `WebSearch` — no network
- `Agent` — extract subagents do not spawn further subagents
- Any write outside `esper/`

Note: The main `/integrate` orchestrator uses `Agent` to dispatch extract subagents. The restriction applies to the subagents themselves, not the orchestrator.

### Layer 3: Processing isolation (two-phase pipeline)

The extract/integrate split acts as a sanitization buffer:
1. **Extract** reads raw untrusted content, produces a structured summary in `_staging/`
2. **Integrate** reads only LLM-authored staging content, never raw sources

The LLM's summarization acts as a content filter — prompt injections must survive being summarized to propagate. Not bulletproof, but significantly raises the bar.

`/ember` lint provides ongoing defense — inconsistencies or suspicious content in pages can be flagged during health checks.

## Cog Pipeline Coordination

Existing Cog skills gain Esper awareness:

- **`/housekeeping`** — flags when Cog observations reference topics that should be Esper pages; includes Esper link health in audit
- **`/reflect`** — when mining session transcripts, notices discussions that map to Esper content or suggest new sources to ingest
- **`/foresight`** — draws connections across both systems ("your reading on X connects to your work goal Y")

## Future Extensions

- **`/ember merge`** — combine two topic pages into one, update all references
- **`/ember rename`** — rename a topic, update all inbound links
- **`/ember split`** — break a topic into subtopics
- **Format parsers** — added incrementally: markdown first, then PDF, CSV, HTML, clippings.txt
- **Search tooling** — when Esper outgrows index.md, add qmd or similar local search
- **Confidence scoring** — track source reliability, flag single-source claims
