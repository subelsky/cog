# esper-lint → Read-Only — Implementation Plan

**Spec:** [`../specs/2026-08-14-esper-lint-readonly-design.md`](../specs/2026-08-14-esper-lint-readonly-design.md)
**Repo:** `/workspaces/tools/esper-lint`
**Target version:** 0.3.0

## Environment notes

- Ruby 3.3.8, no bundler. Run tests with
  `ruby -Ilib -Itest -e 'Dir["test/test_*.rb"].each { |f| require "./#{f}" }'`
  or `rake test` (rake 13.2.1 is on PATH). `minitest` 5.20.0 is installed.
- `standardrb` is **not** installed. Skip the lint task; do not add it as a gate.
- Baseline capture before any edit, for the regression check at the end:
  `ruby -rpathname -rset bin/esper-lint check --esper-dir /workspaces/Synergy/esper > /tmp/baseline.json`
  (the `-r` flags are the bug being fixed — they are not needed after step 1).

## Tasks

### 1. Fix the require bug (do this first — nothing else is testable without it)

- `lib/esper_lint.rb`: add `require "pathname"` and `require "set"` above the existing
  `require_relative` block.
- `Gemfile`: add `ruby ">= 3.3"`.
- `Rakefile`: add a `test:isolated` task that shells out to
  `ruby --disable-gems -Ilib -Itest ...` so a dropped require fails loudly.
- Verify: `ruby bin/esper-lint check --esper-dir /workspaces/Synergy/esper` runs with no `-r` flags.

### 2. Delete the write surface

- Delete `lib/esper_lint/{fixes,mutations,git}.rb` and their `require_relative` lines.
- Delete `test/test_{fixes,mutations,git}.rb`.
- Delete `test_cli.rb::test_fix_then_check_reports_no_fixable_findings` and
  `test_cli.rb::test_fix_refuses_dirty_tree`.
- Keep all fixtures — `test_checks.rb` / `test_queries.rb` still use them.
- `cli.rb`: drop `fix` and `add-source` from `SUBCOMMANDS`, delete `run_fix` and `run_add_source`
  and their `dispatch` branches.
- Verify: `grep -rn "File.write\|Fixes\|Mutations\|EsperLint::Git" lib/` returns nothing.

### 3. Consolidate `index_drift`

- `checks.rb`: remove the `count_mismatch` arm from `Checks.index_drift` (the third block, which
  loops `repo.index_rows` comparing counts). Keep `missing_from_index` and `extra_in_index`.
- Remove the corresponding assertions from `test_checks.rb`.

### 4. Summary-first output

- `cli.rb`: add `--detail CHECK` and `--limit N` (default 50) to the `check` option parser only.
- `run_check` builds the full payload as today, then strips `items` from every check object
  before emitting. When `--detail CHECK` is given, re-attach `items` for that one check,
  truncated to `--limit`; when truncated add `items_truncated: true` and `items_shown: N`.
- Unknown `--detail` value → `INVALID_ARGUMENT`, exit 2.
- Scalar fields (`total`, `by_class`, `threshold`, `stale_days_threshold`) always survive.
- `build_meta`: delete the `ran_at` key. Drop the now-unused `require "time"` if nothing else
  needs it.
- Query subcommands (`sources`/`topics`/`tags`/`manifests`) are unchanged — they keep returning
  full `results`.

### 5. Version and help

- `version.rb` → `0.3.0`.
- `cli.rb` `print_help`: remove `fix`, `add-source`, and the `DIRTY_TREE` / `GIT_UNAVAILABLE` /
  `UNKNOWN_TOPIC` / `UNKNOWN_SOURCE` / `MISSING_SOURCES_SECTION` error codes. Document
  `--detail` / `--limit`. Update the examples block — drop the two fix/add-source examples.
- `README.md`: regenerate the usage block; remove the fix/mutation lines and the
  `Bash(bin/esper-lint fix *)` permission suggestion.

### 6. New tests

In `test_cli.rb`:
- default `check` output has no `items` key on any check
- `--detail orphans` attaches `items` to orphans and to no other check
- `--limit 5` truncates and sets `items_truncated` / `items_shown`
- `--detail bogus` exits 2 with `INVALID_ARGUMENT`
- `fix` and `add-source` exit 2 as unknown subcommands
- `meta` has no `ran_at` key

## Verification (all must pass before reporting done)

```
rake test                                                   # green
rake test:isolated                                          # green
ruby bin/esper-lint check --esper-dir /workspaces/Synergy/esper | wc -c    # < 1000
ruby bin/esper-lint check --esper-dir /workspaces/Synergy/esper | jq .checks
```

Totals must match this baseline exactly, except `index_drift` which moves 2 → 0 by design:

| check | expected |
|---|---|
| orphans | 335 (stub 293 / fixable 0 / subthreshold 42) |
| source_count_mismatches | 2 |
| missing_topic_candidates | 42 |
| missing_connections | 0 |
| stale_manifests | 7 |
| duplicate_sources | 0 |
| index_drift | 0 |

Also confirm `esper/` is untouched: `cd /workspaces/Synergy/esper && git status --porcelain`
must be empty after every command above.

## Out of scope

`.claude/commands/esper.md` and `.claude/settings.local.json` live in the Synergy repo and are
handled there, not by this plan.
