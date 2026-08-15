# esper-lint

Ruby CLI toolkit for the [Esper knowledge base](../../docs/superpowers/specs/2026-04-11-esper-design.md). Provides deterministic lint and query primitives so orchestrators (e.g. Claude) can stop writing inline bash/awk/sed/python.

**Read-only.** No subcommand writes to disk — fixes are hand-edits.

See [`docs/superpowers/specs/2026-08-14-esper-lint-readonly-design.md`](../../docs/superpowers/specs/2026-08-14-esper-lint-readonly-design.md) for the current design spec, and [`2026-05-05-esper-lint-design.md`](../../docs/superpowers/specs/2026-05-05-esper-lint-design.md) for the original.

## Install

```
bundle install
```

Requires Ruby >= 3.3.

## Usage

```
esper-lint check                                  # all 7 lint checks, counts only, JSON to stdout
esper-lint check --detail orphans                 # add the items array for one check
esper-lint check --detail orphans --limit 20      # cap the items (default 50)
esper-lint sources --orphan                       # list orphan source pages
esper-lint sources --orphan --fixable             # orphans whose tags match an existing topic
esper-lint sources --tag mindfulness              # sources tagged 'mindfulness'
esper-lint sources --topic ai-products            # sources linked from a specific topic
esper-lint topics --count-mismatch                # topics where source_count drifts
esper-lint topics --missing-connections           # topics with no Connections section
esper-lint tags --threshold 3 --missing-page      # missing-topic candidates
esper-lint manifests --stale --stale-days 30      # stale source manifests
esper-lint version
esper-lint help
```

`check` returns counts only; use `--detail CHECK` for one check's items, or the query subcommands
(`sources` / `topics` / `tags` / `manifests`), which always return full `results`. When `--limit`
truncates, the check object carries `items_truncated: true` and `items_shown: N`.

`check` exits 1 when any finding is present (for CI/scripting). Queries exit 0 on success and 2 on error. `--esper-dir PATH` defaults to `./esper`.

### Sample output

```
$ esper-lint sources --orphan --esper-dir ./esper | jq '.total, .results[].slug'
6
"source-fixable-orphan"
"source-shared-tag-1"
"source-shared-tag-2"
"source-shared-tag-3"
"source-stub-twin-9359a1"
"source-subthreshold-orphan"
```

## Test

```
rake test              # standard run
rake test:isolated     # same suite under `ruby --disable-gems`, to catch missing requires
```

## Lint

```
bundle exec standardrb
```

`standard` is optional — the Rakefile skips the lint task when the gem isn't installed.

## Permissions allowlist (for Claude Code in Synergy)

After symlinking the binary to `bin/esper-lint` in the Synergy repo, add to `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(bin/esper-lint:*)"
    ]
  }
}
```
