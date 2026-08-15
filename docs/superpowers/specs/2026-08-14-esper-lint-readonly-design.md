# esper-lint → Read-Only, Summary-First — Design

**Date:** 2026-08-14
**Status:** Draft, awaiting user review
**Location:** `tools/esper-lint/` inside the Synergy repo (moved here 2026-08-15 from the standalone `tools` repo)
**Supersedes the write half of:** [`2026-05-05-esper-lint-design.md`](./2026-05-05-esper-lint-design.md)
**Implementation order:** first of three (this → container split → cog re-baseline)

## Problem

`esper-lint` v0.2.0 is ~1,060 lines of library code plus ~966 lines of tests, exposing 9
subcommands. It was built to save Claude from writing inline bash/awk/sed during `/esper` runs.
Measured against the real knowledge base (66 topics, 2,942 sources), it does the opposite of
what it was built for, and its write paths are not trustworthy.

### It is broken outside its author's Ruby

`lib/esper_lint/repo.rb` uses `Pathname` and `Set`; `lib/esper_lint.rb` requires neither. Under
Ruby 3.3 the tool dies on its first call:

```
repo.rb:12:in 'initialize': uninitialized constant EsperLint::Repo::Pathname (NameError)
```

It works only because Ruby 4.x default-loads both. Nothing in the test suite catches this,
because `test_helper.rb` runs under the same Ruby that hides the bug.

### Three write paths lose data

1. **`Fixes.rebuild_index`** overwrites `esper/index.md` wholesale from a hardcoded
   `INDEX_TEMPLATE_HEADER` plus generated rows. Any hand-written prose in `index.md` outside the
   table is destroyed with no warning. It also builds each row's count from *frontmatter*
   `source_count` rather than the actual link count it computed moments earlier, so a stale
   frontmatter value is laundered into the index as truth.
2. **`Fixes.rewrite_sources_section`** (used by `dedup_sources` and `add-source`) reconstructs
   the entire `## Sources` block from parsed `[[pages/sources/...]]` links. Any other content in
   that section — annotations, comments, sub-headings, blank-line grouping — is silently dropped,
   and the surviving list is re-sorted.
3. **`Fixes.update_source_count`** runs `text.sub(/^source_count:\s*\d+\s*$/, ...)` against the
   **whole file**, unanchored to frontmatter. A topic page that quotes `source_count: 3` inside a
   fenced code block gets that line rewritten instead of its frontmatter. The fallback branch is
   worse: it inserts after the first `^---\s*\n` in the document, which on a page with a
   horizontal rule before its frontmatter is not the frontmatter at all.

The `Git.working_tree_clean?` gate exists solely to make these survivable. Remove the writes and
the gate has nothing left to guard.

### It costs tokens instead of saving them

One `esper-lint check` against the real Esper emits **40,694 bytes** of JSON. 37,724 bytes of
that — 93% — is the `orphans` item list.

### Most checks find nothing, and the flagship fix has no work to do

| Check | Findings | Notes |
|---|---|---|
| `orphans` | 335 | 293 untagged stubs, 42 sub-threshold, **0 fixable** |
| `missing_topic_candidates` | 42 | |
| `stale_manifests` | 7 | |
| `source_count_mismatches` | 2 | |
| `index_drift` | 2 | both `count_mismatch` — *duplicates the row above* |
| `missing_connections` | 0 | |
| `duplicate_sources` | 0 | |

`fixable` orphans is zero, so `add-source` — the reason `Mutations` and `Git` exist — currently
has nothing to act on. The 293 untagged stubs are an ingestion-quality problem that belongs to
`/integrate`; no linter can resolve them.

## Goals

- No code path in the tool writes a file.
- Default `check` output fits comfortably in context (~400 bytes, down from ~40 KB).
- The tool runs on the Rubies actually installed on the host and in containers.
- Detail is available on demand, bounded, and per-check.

## Non-goals

- Improving Esper data quality (the 293 stubs are `/integrate`'s problem, tracked separately).
- Adding new checks.
- Rewriting the tool in another language — the test suite and fixture corpus are worth keeping.
- Changing the JSON envelope shape beyond what is specified below.

## Design

### Deletions

| Path | Reason |
|---|---|
| `lib/esper_lint/fixes.rb` | all three lossy write paths |
| `lib/esper_lint/mutations.rb` | `add-source`; 0 fixable orphans to act on |
| `lib/esper_lint/git.rb` | dirty-tree gate; only existed to guard the writes |
| `test/test_fixes.rb` | |
| `test/test_mutations.rb` | |
| `test/test_git.rb` | |
| `test_cli.rb::test_fix_then_check_reports_no_fixable_findings` | |
| `test_cli.rb::test_fix_refuses_dirty_tree` | |

Fixtures stay. `test_checks.rb` and `test_queries.rb` reference
`topic-duplicate-sources`, `source-fixable-orphan`, and `manifest-opaque.yml`, so no fixture is
orphaned by these deletions.

Error codes `DIRTY_TREE`, `GIT_UNAVAILABLE`, `UNKNOWN_TOPIC`, `UNKNOWN_SOURCE`, and
`MISSING_SOURCES_SECTION` become unreachable and come out of the help text. `EsperLint::Error`
itself stays — `ESPER_DIR_MISSING`, `INDEX_MISSING`, `MALFORMED_FRONTMATTER`, and
`INVALID_ARGUMENT` are all still raised.

### Subcommand surface

Kept: `check`, `sources`, `topics`, `tags`, `manifests`, `help`, `version`.
Removed: `fix`, `add-source`.

`SUBCOMMANDS` shrinks accordingly, so `esper-lint fix` exits 2 with
`INVALID_ARGUMENT: unknown subcommand: fix` rather than silently doing nothing.

### Output contract

```
esper-lint check                                # counts only
esper-lint check --detail orphans               # items for one check, capped
esper-lint check --detail orphans --limit 20    # default limit 50
```

Default `check` payload:

```json
{
  "meta": {"esper_dir": "/…/esper", "tool_version": "0.3.0", "subcommand": "check"},
  "summary": {"topics": 66, "sources": 2942, "manifests": 9, "checks_with_findings": 4},
  "checks": {
    "orphans": {"total": 335, "by_class": {"stub": 293, "fixable": 0, "subthreshold": 42}},
    "source_count_mismatches": {"total": 2},
    "missing_topic_candidates": {"total": 42, "threshold": 3},
    "missing_connections": {"total": 0},
    "stale_manifests": {"total": 7, "stale_days_threshold": 30},
    "index_drift": {"total": 0},
    "duplicate_sources": {"total": 0}
  }
}
```

Rules:

- Each check object keeps its existing scalar fields (`total`, `by_class`, `threshold`,
  `stale_days_threshold`). Only the `items` array is withheld.
- `--detail CHECK` adds `items` to that one check and nothing else. Unknown check name →
  exit 2, `INVALID_ARGUMENT`.
- `--limit N` (default 50) caps the returned `items`. When truncated, the check object also
  carries `"items_truncated": true` and `"items_shown": N` so the caller knows to narrow rather
  than assume it saw everything.
- `--detail` and `--limit` apply to `check` only. The `sources` / `topics` / `tags` /
  `manifests` query subcommands are already filtered by their own flags and keep returning full
  `results`; they are the intended path for "show me the actual items."

**`meta.ran_at` is removed.** A timestamp that changes on every invocation defeats prompt caching
across otherwise-identical calls and carries no information the caller lacks.

Exit codes are unchanged: `0` success, `1` `check` found something, `2` error.

### Check consolidation

`index_drift` loses its `count_mismatch` arm. That arm re-derives exactly what
`source_count_mismatches` reports — both currently surface the same 2 findings — but from the
index table rather than from disk, so a caller sees each drift twice and cannot tell it is one
problem. The `missing_from_index` and `extra_in_index` arms stay; nothing else computes those.

`missing_connections` and `duplicate_sources` stay. Each is ~5 lines and both find 0 today, but
that is a fact about the current data, not about their worth.

### Ruby compatibility

- Add `require "pathname"` and `require "set"` to `lib/esper_lint.rb`.
- Add `ruby ">= 3.3"` to the `Gemfile` — the tool uses no 4.x-only syntax, and 3.3 is what ships
  in the containers.
- Add a `rake test:isolated` task that runs the suite with `RUBYOPT=--disable-gems` so
  missing-require regressions surface in CI rather than at first use.

### Versioning

`0.2.0` → **`0.3.0`**. Removing subcommands is breaking; pre-1.0 this is a minor bump.

## Downstream changes

Originally these lived in a separate repository from the tool. Since the 2026-08-15 move they are
all in this repo, so they land in one change set.

**`.claude/commands/esper.md`** — delete the `### Fixing — what the CLI handles vs. what you do`
and `### Auto-fix protocol` sections (~30 lines). Replace with a short "Fixing" section:

- `source_count` mismatches → read the topic's frontmatter, `Edit` the integer. For the current
  2 findings this is cheaper and safer than the machinery it replaces.
- Duplicate `## Sources` entries → `Edit` the list directly.
- Index drift → `Edit` `index.md`.
- Everything else (Connections, syntheses, promoting candidates) was already hand-edited.

Update the tooling table: drop `fix` and `add-source`, add `check --detail`. Drop the
`### Known caveats` bullet about `fix` requiring a clean git tree — no longer applicable. The
`cursor.kind: opaque` caveat stays; that behavior is unchanged.

**`.claude/settings.local.json`** — remove `Bash(bin/esper-lint fix *)`.

**`esper-lint` README** — regenerate the usage block; drop the fix/mutation examples.

## Testing

- Existing `test_checks.rb`, `test_queries.rb`, `test_parsing.rb`, `test_repo.rb` pass unchanged
  except for the `index_drift` count-mismatch assertions, which are removed with the arm.
- New: `check` default output contains no `items` key for any check.
- New: `--detail orphans` returns `items` for orphans and for no other check.
- New: `--limit` truncates and sets `items_truncated` / `items_shown`.
- New: `--detail bogus` exits 2 with `INVALID_ARGUMENT`.
- New: `fix` and `add-source` exit 2 as unknown subcommands.
- New: the isolated-require task fails if `pathname` or `set` is dropped again.

## Verification

Run against the real knowledge base, not just fixtures:

```
ruby bin/esper-lint check --esper-dir /workspaces/Synergy/esper | wc -c   # expect < 1000
ruby bin/esper-lint check --esper-dir /workspaces/Synergy/esper | jq .    # expect same totals
                                                                          # as the 0.2.0 baseline
```

Baseline totals to match: orphans 335 (stub 293 / fixable 0 / subthreshold 42),
`source_count_mismatches` 2, `missing_topic_candidates` 42, `stale_manifests` 7,
`missing_connections` 0, `duplicate_sources` 0. `index_drift` moves from 2 to 0 — that is the
intended consolidation, not a regression.

## Risks

- **Losing a fix you actually wanted.** Mitigated by the finding counts: the only mechanical work
  currently available is 2 `source_count` integers. If mismatches later grow into the dozens,
  a properly frontmatter-scoped `fix --source-counts` can be reintroduced — YAML-parsed, not
  regex-substituted.
- **`--limit` hiding findings.** Mitigated by `items_truncated` being explicit in the payload.
- **Ruby floor.** `>= 3.3` is asserted from the container's `ruby 3.3.8`; confirm the host's
  version before landing and lower the floor if the host is older.

## Success criteria

- `grep -rn "File.write" lib/` returns nothing.
- Default `check` output is under 1 KB and reports the same totals as the 0.2.0 baseline.
- `bundle exec rake test` and the isolated-require task both pass on Ruby 3.3.
- `/esper` lint mode runs end-to-end with no reference to `fix` or `add-source`.
