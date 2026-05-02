Use this skill to query or health-check the Esper knowledge base. Trigger if the user says "esper", "what do I know about", "search esper", "esper lint", "knowledge check", or similar query/maintenance requests.

## Domain

Esper knowledge base — query and maintenance.

## Modes

`/esper` operates in two modes based on the user's request:

- **Query mode** (default): "What do I know about X?", "Find connections to Y"
- **Lint mode**: "esper lint", "check esper health", "esper maintenance"

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

```markdown
## [{today's date}] esper:lint
- Orphan source pages: {count} ({list or "none"})
- Stale topics: {count} ({list or "none"})
- Missing topics: {count} suggestions ({list or "none"})
- Missing cross-refs: {count} suggestions ({list or "none"})
- Source coverage gaps: {count} ({list or "none"})
- Index accuracy: {ok or list of issues}
```

Then present the findings to the user with recommended actions.

### Auto-fix options:

After reporting, offer to fix issues:
- "Create missing topic pages?" — for themes at 3+ sources
- "Update stale syntheses?" — rewrite Current Synthesis sections
- "Rebuild index?" — regenerate index.md from actual topic pages
- "Link orphan source pages?" — add them to relevant topics

Only fix with user approval. Report what was fixed in the log.

---

## Context

This is the query and maintenance interface for Esper. It sits alongside `/integrate` (which ingests sources). `/esper` is what the user invokes when they want to search their knowledge base or check its health.

The skill lives at `.claude/commands/esper.md` alongside existing Cog skills.
