# esper-lint — Design Spec

> **Partly superseded.** v0.3.0 (2026-08-14) removed every write path — `fix`, `add-source`, and
> the `Fixes`/`Mutations`/`Git` modules — and made `check` summary-first. Sections below that
> describe mutations or safe-fixes are historical. See
> [`2026-08-14-esper-lint-readonly-design.md`](./2026-08-14-esper-lint-readonly-design.md).

**Date:** 2026-05-05
**Author:** Mike Subelsky (with Claude)
**Status:** Approved for implementation

## Purpose

`esper-lint` is a focused Ruby CLI toolkit that gives Claude (or any orchestrator) deterministic data-gathering and safe-fix primitives for the [Esper knowledge base](./2026-04-11-esper-design.md). It replaces the ad-hoc grep/awk/sed/python scripts Claude currently writes inline during `/esper` skill runs.

The tool covers the **80% of cases encountered in practice**, not every hypothetical maintenance scenario. It exists so that:

1. **Claude stops writing the same buggy regexes.** Real bug from a recent run: a unicode-naive orphan-detection regex `[a-z0-9-]+` silently misclassified 5 source pages with accented characters as orphans, producing false-positive "fixable" findings.
2. **Mutations preserve invariants atomically.** Hand-edited Sources lists drift out of sync with `source_count` frontmatter. The tool guarantees they don't.
3. **Claude reasons about the knowledge base via JSON, not by parsing prose.** Every subcommand emits structured output suitable for jq filtering or programmatic consumption.

The tool deliberately does **not** make semantic judgments. It does not decide which topic an orphan belongs to, whether a missing-topic candidate should be promoted or subsumed, or how to write a synthesis. Those decisions stay with the orchestrator (Claude).

## Scope

### In scope (v1)

**Lint checks (read-only):**
1. Orphan source pages (with classification: stub / fixable / subthreshold)
2. `source_count` frontmatter mismatch with actual `## Sources` link count
3. Missing topic candidates (tag frequency ≥ threshold with no matching topic page)
4. Topic pages missing a `## Connections` section
5. Source manifest cursor staleness (null or older than threshold)
6. Index drift (topic files on disk vs. entries in `index.md`)
7. Duplicate Sources entries (same source slug listed multiple times in one topic)

**Safe fixes (mutating):**
1. Bump `source_count` in topic page frontmatter to match actual link count
2. Dedup duplicate entries in `## Sources` lists
3. Rebuild `index.md` from current topic page frontmatter and L0 headers

**Query primitives (read-only, parameterized):**
- List source pages, optionally filtered by orphan status, tag, or linking topic
- List tags, optionally filtered by frequency threshold or "no topic page"
- List topic pages, optionally filtered by count-mismatch or missing-connections
- List source manifests, optionally filtered to stale ones

**Targeted mutation (single-purpose):**
- Add a source slug to a topic page's `## Sources` list (sort + dedup + bump count)

### Out of scope (v1)

- Semantic suggestions ("this orphan should go in topic X")
- Mutating source pages (source pages are immutable post-ingest)
- Adding or modifying `## Connections` sections (judgment-driven; hand-edit)
- Removing source links from topics (rare; hand-edit when needed)
- Creating new topic page stubs (judgment-driven)
- Rewriting topic syntheses (LLM work, not deterministic)
- Following or auditing `[[wiki-links]]` outside the source/topic layer
- Multi-repo support (one esper directory per invocation)

## Background — what Claude actually did

The previous `/esper lint` run executed the following bash/python ad hoc:

| Step | Mechanism | Issue uncovered |
|------|-----------|-----------------|
| Count source/topic pages | `ls \| wc -l` | Trivial, but repeated |
| Detect orphans | `grep -hoE '\[\[(pages/sources/)?[a-z0-9-]+(-[a-f0-9]+)?\]\]' ... \| sort \| comm` | Regex dropped unicode slugs (5 false orphans) |
| Source-count mismatch | awk loop comparing frontmatter to actual link count | Worked, but tedious |
| Tag frequency | awk over `topics:` arrays + `uniq -c` | Worked, but tedious |
| Cursor freshness | grep `cursor:` block in YAML manifests | Worked |
| Index drift | `comm` between disk topic list and grep'd index entries | Worked |
| Classify orphans (fixable vs subthreshold) | nested bash loops checking tag-to-topic-file matches | Worked |
| Bump `source_count` | inline Python script | Caused drift when interacting with parallel synthesis agents |
| Add source links | inline Python script | Inserted duplicates that needed `set()` dedup, masking the unicode regex bug |
| Rebuild index | inline Python script | Worked |

Total surface area Claude reinvented from scratch: roughly 200 lines of bash + Python, with at least one substantive bug. `esper-lint` consolidates this into a tested Ruby tool.

## CLI surface

Single binary `esper-lint`, dispatched by subcommand. The binary lives at `tools/esper-lint/` in this repo (it lived in a separate `tools` project until 2026-08-15) and is symlinked to `bin/esper-lint`. The implementation does not need to know about the symlink.

### Subcommands

```
esper-lint check [options]
esper-lint fix [options]
esper-lint sources [options]
esper-lint topics [options]
esper-lint tags [options]
esper-lint manifests [options]
esper-lint add-source TOPIC_SLUG SOURCE_SLUG [options]
esper-lint help [SUBCOMMAND]
esper-lint version
```

Calling `esper-lint` with no subcommand is equivalent to `esper-lint check`.

### Global options

| Flag | Default | Purpose |
|------|---------|---------|
| `--esper-dir PATH` | `./esper` | Esper root directory |
| `--tag-threshold N` | `3` | Minimum tag frequency for missing-topic candidates |
| `--stale-days N` | `30` | Manifest cursor age threshold in days |

### Per-subcommand options

| Subcommand | Flag | Effect |
|------------|------|--------|
| `sources` | `--orphan` | Only sources not linked from any topic page |
| `sources` | `--fixable` | (Combined with `--orphan`) Only orphans whose `topics:` frontmatter includes at least one existing topic page |
| `sources` | `--tag TAG` | Only sources whose `topics:` frontmatter includes TAG |
| `sources` | `--topic SLUG` | Only sources linked from the given topic page |
| `topics` | `--count-mismatch` | Only topics where `source_count` ≠ actual link count |
| `topics` | `--missing-connections` | Only topics with no `## Connections` section |
| `tags` | `--missing-page` | Only tags ≥ threshold with no matching topic page |
| `manifests` | `--stale` | Only manifests with null cursor or staleness ≥ threshold |
| `fix` | (none) | Runs all three safe fixes; refuses if git tree dirty |
| `add-source` | (positional args) | TOPIC_SLUG and SOURCE_SLUG required |

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success: lint clean (zero findings), or mutation completed (whether or not anything was applied), or query returned (whether or not results were non-empty) |
| `1` | Lint reported one or more findings (used by `check` only) |
| `2` | Error (missing dir/file, malformed input required by the operation, dirty tree on `fix`, unknown topic/source on `add-source`, invalid arguments) |

`fix`, `add-source`, and the parameterized queries (`sources`, `topics`, `tags`, `manifests`) never return exit 1 — they're not lint operations. Exit 1 is reserved for `check` so CI/scripting can branch on "needs human attention."

### `fix` clean-tree guard

`fix` shells out: `git status --porcelain -- <esper-dir>` (executed via `Open3.capture3` with cwd set to `<esper-dir>` or its parent). If output is non-empty, exit 2 with `error.code = "DIRTY_TREE"`. **Prerequisite:** the esper directory must be tracked in git. As of 2026-05-05 it is not yet tracked; the user will add it before relying on `fix`.

## JSON output shapes

Every subcommand emits a JSON object on stdout. Diagnostic warnings (e.g., "skipping malformed file X") go to stderr as JSON lines (one object per line, key `warning`). Errors that terminate execution go to stderr as a single JSON object and trigger exit 2.

### Common envelope

```json
{
  "meta": {
    "esper_dir": "/absolute/path/to/esper",
    "ran_at": "2026-05-05T14:23:11-04:00",
    "tool_version": "0.1.0",
    "subcommand": "check"
  },
  "...payload key varies by subcommand..."
}
```

### `check`

```json
{
  "meta": { ... },
  "summary": {
    "topics": 65,
    "sources": 2144,
    "manifests": 8,
    "checks_with_findings": 3
  },
  "checks": {
    "orphans": {
      "total": 124,
      "by_class": { "stub": 82, "fixable": 0, "subthreshold": 42 },
      "items": [
        {
          "slug": "instapaper-better-know-a-ruby-thing-on-the-use-of-private-methods",
          "class": "stub",
          "tags": [],
          "matching_topics": []
        },
        {
          "slug": "instapaper-deepspeedai-deepspeed",
          "class": "subthreshold",
          "tags": ["ml-infrastructure", "distributed-training"],
          "matching_topics": []
        }
      ]
    },
    "source_count_mismatches": {
      "total": 0,
      "items": []
    },
    "missing_topic_candidates": {
      "total": 43,
      "threshold": 3,
      "items": [
        { "tag": "mindfulness", "count": 6 },
        { "tag": "tools", "count": 5 }
      ]
    },
    "missing_connections": {
      "total": 1,
      "items": ["infrastructure-history"]
    },
    "stale_manifests": {
      "total": 6,
      "stale_days_threshold": 30,
      "items": [
        { "file": "claude-chat.yml", "cursor_kind": "date", "cursor_field": "last_sync", "value": null, "age_days": null },
        { "file": "readwise.yml", "cursor_kind": "date", "cursor_field": "last_processed", "value": "2026-04-12", "age_days": 23 }
      ]
    },
    "index_drift": {
      "total": 0,
      "items": []
    },
    "duplicate_sources": {
      "total": 0,
      "items": []
    }
  }
}
```

`index_drift.items` shape (when present):
```json
{
  "kind": "missing_from_index | extra_in_index | count_mismatch",
  "topic": "ai-products",
  "details": { "disk_count": 297, "index_count": 296 }
}
```

### `fix`

```json
{
  "meta": { ... },
  "applied": {
    "source_count_bumps": [
      { "topic": "podcast", "from": 11, "to": 12 }
    ],
    "dedup_sources": [
      { "topic": "ai-products", "removed": ["instapaper-the-half-life-of-the-ai-stack"] }
    ],
    "index_rebuilt": {
      "rows_before": 64,
      "rows_after": 65,
      "topics_added": ["mindfulness"],
      "topics_removed": [],
      "count_changes": [{ "topic": "hacker-projects", "from": 38, "to": 39 }]
    }
  },
  "post_fix_check": {
    "summary": { ... },
    "checks": { ... }
  }
}
```

### `sources`

```json
{
  "meta": { ... },
  "filters": { "orphan": true, "fixable": true },
  "total": 0,
  "results": [
    {
      "slug": "...",
      "tags": [...],
      "linked_from_topics": [...],
      "is_orphan": true,
      "is_stub": false,
      "matching_topics": [...]
    }
  ]
}
```

### `topics`

```json
{
  "meta": { ... },
  "filters": { "count_mismatch": true },
  "total": 0,
  "results": [
    {
      "slug": "ai-products",
      "source_count_frontmatter": 297,
      "source_count_actual": 296,
      "has_connections": true,
      "l0": "AI products — where generative models fit..."
    }
  ]
}
```

### `tags`

```json
{
  "meta": { ... },
  "filters": { "threshold": 3, "missing_page": true },
  "total": 43,
  "results": [
    { "tag": "mindfulness", "count": 6, "has_topic_page": false },
    { "tag": "tools", "count": 5, "has_topic_page": false }
  ]
}
```

### `manifests`

```json
{
  "meta": { ... },
  "filters": { "stale": true },
  "total": 6,
  "results": [
    {
      "file": "claude-chat.yml",
      "cursor_kind": "date",
      "cursor_field": "last_sync",
      "value": null,
      "age_days": null,
      "is_stale": true
    }
  ]
}
```

### `add-source`

```json
{
  "meta": { ... },
  "applied": {
    "topic": "hacker-projects",
    "source_added": "instapaper-digital-red-queen-...-9359a1",
    "source_count": { "from": 38, "to": 39 },
    "was_already_present": false
  }
}
```

If `was_already_present` is true (the slug already existed in `## Sources`), the file is not modified, exit code is `0`, and `source_count.from == source_count.to`.

### Errors

```json
{
  "error": {
    "code": "DIRTY_TREE",
    "message": "git working tree under <path> has uncommitted changes; refusing to apply fix",
    "path": "/Users/subelsky/Synergy/esper",
    "details": {
      "porcelain_output": "?? esper/pages/topics/new-topic.md\n M esper/index.md"
    }
  }
}
```

Defined error codes:

| Code | Triggered by |
|------|--------------|
| `ESPER_DIR_MISSING` | `--esper-dir` path doesn't exist or isn't a directory |
| `INDEX_MISSING` | `<esper-dir>/index.md` doesn't exist |
| `DIRTY_TREE` | `fix` invoked with uncommitted changes under esper-dir |
| `MALFORMED_FRONTMATTER` | YAML parse failure on a file required for the requested operation |
| `UNKNOWN_TOPIC` | `add-source` invoked with a topic slug that has no matching topic file |
| `UNKNOWN_SOURCE` | `add-source` invoked with a source slug that has no matching source file |
| `INVALID_ARGUMENT` | Conflicting flags, missing positional args, etc. |

## Parsing rules

### Topic page

Format (line 1 is the L0 header, frontmatter follows). The L0 header is matched on **line 1 only** with the regex `\A<!--\s*L0:\s*(.*?)\s*-->\s*\z`. Subsequent occurrences of the pattern elsewhere in the file are not L0 headers.

```markdown
<!-- L0: Brief one-line summary, max 80 chars -->
---
created: YYYY-MM-DD
source_count: N
---

# Title

## Current Synthesis
...freeform prose...

## Optional middle sections (Craft Notes, How to use this topic, etc.)
...

## Sources
- [[pages/sources/SLUG_1]]
- [[pages/sources/SLUG_2]]
...

## Connections
- [[pages/topics/OTHER]] — optional description
- ...
```

Required for the tool:
- `<!-- L0: TEXT -->` on line 1 (used for index summary)
- YAML frontmatter with at least `source_count: N`
- `## Sources` section with zero or more `- [[pages/sources/SLUG]]` lines

Optional:
- `## Connections` section (its absence is a finding, not an error)

The tool preserves all sections it does not touch. When mutating Sources or frontmatter, it must not reorder, remove, or modify other sections.

### Source page

Required for the tool:
- YAML frontmatter with `topics: [...]` (may be empty array)

Slug is the filename stem (e.g., `pages/sources/instapaper-foo.md` has slug `instapaper-foo`).

A source page is classified as a **stub** when its `topics` array is empty.

### Source manifest

Located in `<esper-dir>/sources/*.{yml,yaml}`. The tool reads the top-level `cursor:` block, which has these fields:

- `kind:` (optional) — `date` or `opaque`. Defaults to `date` if absent.
- `last_processed:` or `last_sync:` — the cursor value. For `kind: date`, must be a date string `YYYY-MM-DD` or null. For `kind: opaque`, may be any string or null.

If both `last_processed:` and `last_sync:` are absent or null, the manifest is treated as "never processed" regardless of `kind`. For `kind: opaque` with a non-null value, the tool treats the cursor as **fresh** and does not compute an age — the producing skill (e.g. `/integrate`) owns currency, since the value is a producer-defined position pointer (slug, hash, offset) rather than a wall-clock date.

### Index

`<esper-dir>/index.md`. Recognized table rows match (whitespace tolerant):

```
| [[pages/topics/SLUG]] | N | YYYY-MM-DD | summary text |
```

Anything else is preserved as-is when rebuilding (header, prose, etc.).

### Wiki-link extraction

When extracting source-page references from topic pages, match `\[\[pages/sources/([^\]]+)\]\]` (anything inside the brackets after `pages/sources/`, **not** restricted to ASCII). The tool MUST handle slugs with unicode characters (é, á, ç, ö, ü) and hash-suffix collision twins (`-9359a1`).

When extracting `topics:` from source page frontmatter, parse with the YAML library, never with regex.

## Check definitions (semantics)

### 1. Orphans

A source page is an orphan if no topic page's `## Sources` section contains a wiki-link to it.

**Classification:**
- `stub` — `topics: []` in source frontmatter
- `fixable` — has tags AND at least one tag matches an existing topic page slug
- `subthreshold` — has tags AND none of the tags match an existing topic page slug

`matching_topics` lists which existing topics the source's tags point to (empty for stub and subthreshold).

### 2. source_count mismatch

For each topic page, compare `source_count` in frontmatter to the count of **unique** source slugs referenced by `^- \[\[pages/sources/SLUG\]\]` lines in `## Sources`. Report any mismatch. Duplicate entries collapse before the comparison, so a topic is not double-flagged by both `source_count_mismatches` and `duplicate_sources`.

### 3. Missing topic candidates

Tally tag frequency across all source pages (tags from `topics:` arrays, ignoring empty arrays). Report tags whose frequency is ≥ `--tag-threshold` and which do not have a matching topic page (`pages/topics/{tag}.md` does not exist).

### 4. Missing connections

A topic page lacks a Connections section if there is no `## Connections` heading anywhere in the file. Report by topic slug.

### 5. Stale manifests

For each YAML file in `<esper-dir>/sources/`:
- Read top-level `cursor:` block; default `kind:` to `date` if absent.
- Determine `cursor_field` (whichever of `last_processed` / `last_sync` is present, preferring `last_processed` if both exist).
- Apply this matrix:

| `kind` | `value` | Behavior |
|---|---|---|
| `date` | parseable `YYYY-MM-DD` | Compute `age_days`. Stale if `age_days >= --stale-days`. |
| `date` | null | Stale; `age_days: null`. |
| `date` | unparseable | Warn `unparseable_cursor_date`. Stale; `age_days: null`. |
| `opaque` | non-null string | **Fresh** (the producing skill owns currency). `age_days: null`. |
| `opaque` | null | Stale; `age_days: null`. |

`cursor_kind` in output is the `kind:` discriminator (`"date"` | `"opaque"`). `cursor_field` reports which key (`last_processed` | `last_sync`) carried the value.

### 6. Index drift

Compare:
- Set of topic page slugs on disk (from `<esper-dir>/pages/topics/*.md`)
- Set of topic slugs in `index.md` table

Report:
- Topics on disk but not in index → `kind: missing_from_index`
- Topics in index but not on disk → `kind: extra_in_index`
- Topics where index `source_count` differs from disk `source_count` → `kind: count_mismatch`

### 7. Duplicate sources

For each topic page, count occurrences of each source slug in `## Sources`. Any slug appearing more than once is a duplicate. Report by topic with the list of duplicated slugs.

## Fix definitions (semantics)

### 1. Bump source_counts

For every topic page where `source_count` differs from the actual link count, rewrite the frontmatter to match the actual count. Preserve all other frontmatter fields and the rest of the file. If `source_count` is missing entirely from the frontmatter, add it (positioned after `created:` if present, otherwise as the last frontmatter field) and emit a stderr warning.

### 2. Dedup sources

For every topic page with duplicate entries in `## Sources`, remove duplicates (keep first occurrence). After dedup, re-sort the section alphabetically (case-insensitive, by slug). Then bump `source_count` to match.

### 3. Rebuild index

Generate `<esper-dir>/index.md` from current state:
- Preamble (L0 header, `# Esper Index`, `## Topics`, table header) — fixed template
- One row per topic page, sorted by `source_count` descending, then by slug ascending
- For each row:
  - `Topic` column: `[[pages/topics/SLUG]]`
  - `Sources` column: `source_count` from frontmatter (post-bump)
  - `Last Updated` column: today's date if topic was modified by this `fix` invocation OR if topic is new since last index; otherwise preserve previous date from existing index
  - `Summary` column: text from the topic's L0 header (`<!-- L0: TEXT -->`); if no L0, use empty string and emit a warning to stderr

The fix must be idempotent: running `fix` twice in a row produces no changes on the second run.

## Architecture

Single Ruby file (or small handful, see below), pure stdlib. No gems beyond the dev linter (`standard`).

### File layout (`tools/esper-lint/` in this repo; a separate `tools` project before 2026-08-15)

```
esper-lint/
├── Gemfile                  # gem "standard", group :development
├── Gemfile.lock
├── README.md
├── bin/
│   └── esper-lint           # executable entry point
├── lib/
│   └── esper_lint/
│       ├── cli.rb           # OptionParser dispatch, JSON output
│       ├── repo.rb          # EsperRepo: load + cache files
│       ├── checks.rb        # one method per lint check
│       ├── fixes.rb         # one method per safe fix
│       ├── queries.rb       # sources/topics/tags/manifests filters
│       ├── mutations.rb     # add_source
│       ├── parsing.rb       # frontmatter, sources extraction, manifest YAML
│       ├── git.rb           # clean-tree check via Open3
│       └── version.rb       # VERSION constant
└── test/
    ├── fixtures/
    │   └── esper/           # tiny replica covering edge cases (see below)
    ├── test_checks.rb
    ├── test_fixes.rb
    ├── test_queries.rb
    ├── test_mutations.rb
    ├── test_parsing.rb
    └── test_cli.rb
```

The `bin/esper-lint` script is a thin shim:

```ruby
#!/usr/bin/env ruby
require_relative "../lib/esper_lint/cli"
exit EsperLint::CLI.run(ARGV)
```

### Module responsibilities

- **`EsperLint::CLI`** — `OptionParser` dispatch, JSON serialization to stdout, exit-code mapping. Catches `EsperLint::Error` and emits the structured error envelope on stderr.
- **`EsperLint::Repo`** — Eager-loads the esper directory: parses every topic page (frontmatter + L0 + Sources list + has-Connections flag), every source page (frontmatter + slug), every manifest (YAML), and the index (parsed table rows). Exposes accessors: `topics`, `sources`, `manifests`, `index_rows`, `topic(slug)`, `source(slug)`. Computes derived sets lazily: orphans, source-link references, etc.
- **`EsperLint::Checks`** — One module method per lint check, takes a `Repo`, returns a hash matching the JSON shape.
- **`EsperLint::Fixes`** — `bump_source_counts(repo)`, `dedup_sources(repo)`, `rebuild_index(repo)`. Each returns the "applied" record.
- **`EsperLint::Queries`** — Parameterized read methods: `sources(repo, orphan:, fixable:, tag:, topic:)`, `topics(repo, count_mismatch:, missing_connections:)`, etc.
- **`EsperLint::Mutations`** — `add_source(repo, topic_slug, source_slug)`. Validates existence, mutates the topic file (sort + dedup + count bump), returns the applied record.
- **`EsperLint::Parsing`** — Pure functions: `parse_frontmatter(text)`, `extract_sources(text)`, `extract_l0(text)`, `parse_index_table(text)`, `format_topic_page(...)`, `format_index(...)`. No I/O.
- **`EsperLint::Git`** — `working_tree_clean?(esper_dir)` via `Open3.capture3("git", "status", "--porcelain", "--", esper_dir.to_s)`.
- **`EsperLint::Error`** — Custom exception class carrying `code`, `path`, `details`.

Eager loading is fine because the largest known esper has ~2200 source pages and ~70 topic pages — well under a second on disk.

## Edge cases

The tool MUST handle these without crashing:

1. **Unicode in slugs.** Source slugs containing `é á ç ö ü ß` etc. are valid. Wiki-link extraction must not restrict to `[a-z0-9-]`.
2. **Hash-suffix collision twins.** `instapaper-foo` and `instapaper-foo-9359a1` are distinct slugs and distinct files.
3. **Empty `## Sources` section.** A new topic page with `source_count: 0` and no link lines under Sources is valid.
4. **Topic page with no `## Connections`.** Flagged in `missing_connections` check; never an error.
5. **Source page with `topics: []`.** Classified as `stub` orphan; never an error.
6. **Manifest with no `cursor:` block.** Treated as never-processed (stale).
7. **Manifest with `cursor:` block but no `last_processed`/`last_sync` keys.** Same as #6.
8. **Malformed YAML frontmatter.** Emit a JSON warning to stderr (`{"warning": "malformed_frontmatter", "path": "..."}`), skip the file, continue. Exception: if a check explicitly needs that file (e.g., `add-source` targeting a malformed topic), exit 2 with `MALFORMED_FRONTMATTER`.
9. **`source_count` field missing from frontmatter.** Treat as 0 for comparison; emit a stderr warning.
10. **Index table row that doesn't parse.** Preserve verbatim during rebuild but flag in the warning stream.
11. **Concurrent file modification.** Out of scope. The clean-tree guard plus single-process invocation is the safety mechanism.

## Mutation invariants

After any mutation completes successfully, the following must hold:

1. For every topic page touched: `source_count` (frontmatter) == count of `^- \[\[pages/sources/SLUG\]\]` lines in `## Sources`.
2. For every topic page touched: `## Sources` contains no duplicate slugs.
3. For every topic page touched: `## Sources` is sorted alphabetically (case-insensitive) by slug.
4. The index is consistent with disk: every topic file has exactly one row, no row points to a non-existent topic, and counts match frontmatter.
5. No file outside `<esper-dir>` is modified.
6. No section other than the targeted one(s) is modified within a touched file.

These invariants are testable and should each have at least one assertion.

## Linter

The Ruby code MUST pass `standardrb` (the [Standard Ruby](https://github.com/standardrb/standard) linter/formatter) without errors or warnings.

- Add `gem "standard"` to the Gemfile in `group :development`
- The CI step (and any local pre-commit) runs `bundle exec standardrb`
- Style is unconfigurable by design (Standard Ruby's central tenet); do not add a `.standard.yml` unless absolutely necessary
- `bundle exec standardrb --fix` auto-fixes most issues

## Testing

Use `minitest` (stdlib). One fixture esper directory under `test/fixtures/esper/` covers all edge cases:

- 6 topic pages: one with each of (clean state, source_count mismatch, missing connections, duplicate sources, unicode-slug source, count = 0)
- 12 source pages: include unicode slugs, hash-suffix collision twin, stub (topics: []), tagged with existing topic, tagged with subthreshold-only tag
- 2 manifests: one with current cursor, one with null cursor
- An index.md that mirrors the disk state

Test categories:

1. **Parsing** — frontmatter/sources/L0/manifest extractors handle each edge case
2. **Checks** — each check returns the expected items for the fixture
3. **Fixes** — each fix produces the expected file diffs; idempotent on second run
4. **Queries** — each filter combination returns the expected subset
5. **Mutations** — `add_source` enforces invariants; rejects unknown topics/sources; idempotent for already-present links
6. **CLI** — exit codes correct for clean / findings / error cases; JSON output validates against expected shape; `fix` refuses on dirty tree
7. **Round-trip** — `fix` then `check` reports zero findings for the fixable subset

Tests should be runnable as `bundle exec rake test` and `bundle exec ruby -Ilib -Itest test/test_*.rb`.

## Performance

Not a concern at v1 scale (~2200 source pages, ~70 topic pages). Eager-loading the entire repo into memory is acceptable. If a future esper grows past ~50k files, revisit lazy loading.

## Security

The tool reads files within `--esper-dir` and shells out only to `git status` (with explicit args, no string interpolation). No network calls, no arbitrary code execution, no shell out beyond the git check.

## Versioning

`EsperLint::VERSION` follows semver. Breaking changes to JSON output shape bump minor pre-1.0 (will bump major post-1.0).

### Release notes

- **0.2.0 (2026-05-13)**: Manifest cursor schema gained a `kind:` discriminator (`date` | `opaque`). JSON output for `stale_manifests` and `manifests` items now includes both `cursor_kind` (the `kind:` discriminator, `"date"` | `"opaque"`) and `cursor_field` (the cursor field name, `"last_processed"` | `"last_sync"`). In v0.1.x, `cursor_kind` had carried the field name — that role moved to `cursor_field`. Consumers parsing manifest JSON must update accordingly. Manifests without an explicit `kind:` default to `date` for backward compatibility.
- **0.1.x (2026-05-05 → 2026-05-08)**: Initial release; bug fixes and tighter spec conformance.

## Permissions allowlist (in Synergy)

After the tool is installed and symlinked to `bin/esper-lint`, add to Synergy's `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(bin/esper-lint:*)"
    ]
  }
}
```

This covers every subcommand and flag combination.

## Future (deferred)

Possible v2+ work, not in scope now:

- `add-connection TOPIC OTHER_TOPIC [--description TEXT]`
- `remove-source TOPIC SOURCE_SLUG`
- `create-topic-stub SLUG --l0 TEXT` (creates the file scaffold; user fills in synthesis)
- `--watch` mode (re-runs on file change)
- Suggesting orphan placement based on tag/title heuristics (still surfaces to LLM for confirmation)
- Linting source page frontmatter (required fields, tag normalization)
- `link-audit` for `[[wiki-links]]` outside the source/topic layer

## Open questions resolved during design

- **Language:** Ruby (user preference; matches stack).
- **CLI dispatcher:** stdlib `OptionParser` (not Thor).
- **Output format:** JSON only (no human text).
- **Fix granularity:** single `fix` subcommand runs all three safe fixes; no per-fix flags.
- **Clean-tree guard:** required for `fix`; uses `git status --porcelain`.
- **Logging:** the tool does NOT auto-append to `esper/log.md`. The orchestrator (Claude or human) logs at the session level.
- **Tag/staleness thresholds:** flags with sane defaults (3 / 30 days).
