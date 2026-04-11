# Memory

## The Core Idea

Cog's memory design draws from the RLM paper (arxiv 2512.24601).

> Memory as environment, not input.

Cog doesn't try to load everything it knows into every conversation. Instead, it structures memory into three tiers — like an office:

- **Hot memory** is your desk. The 30,000-ft view of your current state — top priorities, active projects, what matters right now. Loaded into every conversation automatically. (~25 lines, cross-domain.)
- **Warm memory** is the filing cabinet across the room. Domain-specific files that only get pulled when a skill activates. Ask about your Python project and it walks over to that cabinet — it doesn't pull your grocery list.
- **Glacier** is deep storage across town. Historical archives, indexed with metadata so they're searchable without reading the full contents. Out of the way, but never lost.

The result: Cog can have hundreds of files across dozens of domains and still load only what's relevant — without reading everything up front.

## Progressive Condensation

Two processes:

**Condensation** compresses raw data into increasingly actionable layers:

```
Raw events (voice, photos, PDFs, conversation fragments)
    ↓ capture fast, timestamp, tag
Observations (append-only, per-domain)
    ↓ when 3+ observations cluster on a theme
Patterns (edit-in-place, distilled rules)
    ↓ when active or urgent
Hot Memory (rewrite-freely, ~25 lines cross-domain)
```

**Archival** moves stale data to cold storage:

```
Observations → Glacier (indexed, retrievable on demand)
```

Nothing is ever lost. Active working memory stays lean.

## File Types

| Type | Purpose | Edit Mode | Loaded When |
|------|---------|-----------|-------------|
| `hot-memory.md` | Top-of-mind per domain | Rewrite freely | Every conversation (in system prompt) |
| `observations.md` | Timestamped events | Append only | When skill activates or search hits |
| `entities.md` | People, places, things | Edit in place | When someone/something is mentioned |
| `action-items.md` | Tasks and deadlines | Edit in place | Briefings, triage, when relevant |
| `patterns.md` | Distilled rules | Edit in place | Self-improvement, when behaviour repeats |
| Thread files | Deep single-topic synthesis | Current state: rewrite. Timeline: append | When topic comes up |
| `glacier/` | Archived data | Read only | Only via explicit search |

## Domain Structure

Every domain follows the same anatomy — a directory with standard file types. Domains are defined in `memory/domains.yml` (the [domain registry](/architecture#domain-registry)) and created by the `/setup` skill:

```
memory/
  domains.yml              # Manifest — SSOT for all domains
  hot-memory.md            # Cross-domain top-of-mind
  personal/                # hot-memory, observations, action-items, entities, ...
  work/
    <your-job>/            # Same structure — one dir per domain
    <side-project>/
  cog-meta/                # Cog self-knowledge
  glacier/                 # Archived data by domain
```

Each domain lists its files in the manifest. The pipeline skills all discover domains from this file — no hardcoded paths.

## The Memory Router

Instead of loading all memory into context, Cog gets a **routing index** — a compact map of what exists and where.

Cog uses L0 headers and CLAUDE.md routing conventions to navigate the memory directory. Rather than loading every file, Claude reads the routing table and navigates to the right files based on query type:

- "What's on today?" → `personal/calendar.md`
- "Who's on my team?" → `work/<domain>/entities.md`
- "How's the typing going?" → `personal/keyboard-typing.md` (thread)
- "Update my action items" → domain-specific `action-items.md`

The router means Cog can have hundreds of files across dozens of domains and still know exactly where to look — without reading everything up front.

### L0 Headers — Progressive Context Loading

> Inspired by [OpenViking](https://github.com/volcengine/OpenViking) (ByteDance), which uses L0/L1/L2 tiered loading to reduce token cost and improve routing accuracy.

Think of it like browsing a library. You read the spine of the book to see the title. If it looks relevant, you open it and check the table of contents. Only then do you turn to the chapter you need.

Every memory file has a one-line **L0 summary** near the top — a quick answer to "what would I find if I read this file?" (max 80 characters):

```markdown
# Personal — Entities
<!-- L0: Key people — family, friends, professionals, with bios and key details -->
```

Three-tier loading in practice:

- **L0** — read the spine. One-line summaries across all files (~100 tokens total) for routing decisions
- **L1** — check the table of contents. Domain files loaded when a skill activates or the router selects them
- **L2** — read the chapter. Threads and deep context loaded only when needed

L0 headers are maintained by the pipeline: [Housekeeping](/pipeline/housekeeping) scans for missing headers, [Reflect](/pipeline/reflect) preserves them when reorganising. See the [journal entry](/journal/l0-progressive-loading) for the full story.

#### Grep-Based Retrieval

For pipeline skills, the recommended way to access L0 summaries is a direct grep rather than reading INDEX.md:

```bash
grep -rn "<!-- L0:" memory/{domain}/
```

This extracts every L0 header in a domain with one shell command — no file reads required. Pipeline skills use this as part of a [shell orientation pass](/journal/unix-toolbox-orientation) that scopes work before loading any files. INDEX.md files remain useful as a human-readable reference, but for programmatic routing, grep is faster and cheaper.

## Memory Intelligence

Three research-informed improvements adopted on [Day 23](/journal/memory-intelligence) after surveying 12 LLM memory systems:

**Bi-directional back-linking** (inspired by A-MEM, NeurIPS 2025) — When writing to file A and linking to file B, Cog also updates file B to link back to A. The knowledge graph stays connected in both directions, not just forward references.

**Temporal validity on entities** (inspired by Zep/Graphiti) — When facts change in entity files, the old value is preserved with `since/until` dates and strikethrough:

```
Role: ~~Senior Engineer (since 2023-01, until 2024-12)~~
      → Creative Technologist (since 2024-12)
```

This preserves how understanding evolved — important for a personal AI that tracks real people across years.

**Contradiction detection** (inspired by Mem0) — A systematic consistency sweep runs every [Reflect](/pipeline/reflect) pass. For each domain's hot-memory, reflect verifies factual claims against canonical sources. Resolution: canonical file always wins; more recent wins; more specific wins over summary. Health dates and family-sensitive facts are flagged for user review, not auto-fixed.

## Threads — The Zettelkasten Layer

Threads are **read-optimised synthesis files**. While observations capture raw events (write-optimised), threads pull related fragments into a coherent narrative.

Every thread has the same spine:

- **Current State** — what's true right now (rewrite freely, always current)
- **Timeline** — dated entries, append-only, full detail preserved (never condensed)
- **Insights** — learnings, patterns, what's different this time

### What Does "Raise" Mean?

"Raise" is the verb for creating or updating a thread. When triggered:

1. **Search fragments** — Cog searches observations and memory files for all references
2. **Synthesise** — extract the narrative arc
3. **Write the thread** — create or update with the Current State → Timeline → Insights spine
4. **Link** — thread references source fragments via wiki-links

### Graduation

A thread gets raised when:

- A topic appears in **3+ observations across 2+ weeks**
- The user explicitly says "raise X" or "thread X"
- Scattered fragments no longer serve the topic well

### Rules

- **One file forever** — threads grow long, they don't split or condense
- **Texture is the value** — every entry keeps its full detail, quotes, and dates
- **Fragments never move** — threads reference them, don't replace them
- **Current State is always current** — rewrite it freely as things change

## SSOT

**Single Source of Truth.** Each fact lives in ONE canonical file. Other files reference via wiki-links, never copy.

- Action items → `action-items.md`
- Calendar → `calendar.md`
- People → `entities.md`
- Health → `health.md`

When a canonical file updates, hot-memory adjusts its framing but never duplicates the data.
