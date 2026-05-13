# Manifest Cursor Kind — Design + Implementation Plan

> **For agentic workers:** Self-contained design + tasks for adding a `kind` discriminator to Esper source-manifest cursors so esper-lint stops false-flagging non-date cursors as stale. Spans two repos: `Synergy` (specs, skills, manifest data) and the user's tools project (`esper-lint` Ruby code). Each task is independent.

**Reference docs:**
- Existing esper-lint spec: `docs/superpowers/specs/2026-05-05-esper-lint-design.md`
- Existing fix-up plan: `docs/superpowers/plans/2026-05-07-esper-lint-fixes.md`
- Integrate skill: `.claude/commands/integrate.md`

---

## Motivation

Esper has two kinds of source manifests today:

1. **Time-ordered** (most): `cursor.last_processed: YYYY-MM-DD`. The integrate skill advances this date when it processes new entries chronologically. Example: `readwise.yml`, `research-papers.yml`.
2. **Filesystem-walked** (one): `cursor.last_processed: <slug>`. The integrate skill walks a directory alphabetically and stores the last-processed directory name as the cursor. Example: `esper/sources/instapaper.yaml` with `last_processed: zakelfassi.com_2cfea35833e8`.

The esper-lint tool assumes all cursors are dates. For the slug case, every lint run produces:

```
{"warning":"unparseable_cursor_date","path":".../instapaper.yaml","value":"zakelfassi.com_2cfea35833e8"}
```

…and reports `instapaper.yaml` as stale even though its cursor is current. Two manifest formats, one tool, persistent false positive.

## Design

Add a `kind:` field inside each manifest's `cursor:` block. Two values:

- `date` — value is `YYYY-MM-DD` (or null for never-bootstrapped). esper-lint computes `age_days` and applies the staleness threshold.
- `opaque` — value is an arbitrary string (or null). esper-lint does NOT parse; treats non-null as **fresh**, null as **stale** (never bootstrapped).

Backward compatibility: if `kind:` is absent, esper-lint defaults to `date` and behaves as today (warns on unparseable values, treats as stale). Existing manifests don't break.

### Manifest examples after migration

Time-ordered:
```yaml
source_type: readwise-article
cursor:
  kind: date
  last_processed: 2026-04-12
```

Filesystem-walked:
```yaml
source_type: instapaper-article
cursor:
  kind: opaque
  last_processed: zakelfassi.com_2cfea35833e8
```

Never-bootstrapped (kind set; value null):
```yaml
source_type: claude-chat
cursor:
  kind: date
  last_sync: null
```

### Behavior matrix

| `kind` | `value` | Behavior |
|---|---|---|
| `date` | `YYYY-MM-DD` parseable | Compute age; stale if `age_days >= --stale-days` |
| `date` | null | Stale (never bootstrapped); `age_days: null` |
| `date` | unparseable | Warn `unparseable_cursor_date`; stale; `age_days: null` |
| `opaque` | non-null string | **Fresh** (the producer is the source of truth for currency); `age_days: null` |
| `opaque` | null | Stale (never bootstrapped); `age_days: null` |
| absent | (any) | Default to `date` and apply that row's behavior |

### JSON output shape change

`Checks.stale_manifests` and `Queries.manifests` items currently include:
```json
{ "file": "...", "cursor_kind": "last_processed", "value": "...", "age_days": N, "is_stale": true }
```

After the change, `cursor_kind` is repurposed to mean the *kind* discriminator (`"date"` | `"opaque"`), and the field naming the cursor key (`last_processed` vs `last_sync`) moves to a new field `cursor_field`:

```json
{
  "file": "instapaper.yaml",
  "cursor_kind": "opaque",
  "cursor_field": "last_processed",
  "value": "zakelfassi.com_2cfea35833e8",
  "age_days": null,
  "is_stale": false
}
```

This is a **breaking change** to the JSON shape → bump esper-lint to **0.2.0**.

---

## Tasks

### Task 1: Update esper-lint spec

**Files:**
- `docs/superpowers/specs/2026-05-05-esper-lint-design.md`

- [ ] **Step 1: Edit the "Source manifest" parsing section.**

Replace the current block:

> **Source manifest** — Located in `<esper-dir>/sources/*.{yml,yaml}`. The tool reads the top-level `cursor:` block and looks for `last_processed:` or `last_sync:` keys. Either may be a date string `YYYY-MM-DD` or null. If both are absent or null, the manifest is treated as "never processed."

With:

> **Source manifest** — Located in `<esper-dir>/sources/*.{yml,yaml}`. The tool reads the top-level `cursor:` block, which has these fields:
>
> - `kind:` (optional) — `date` or `opaque`. Defaults to `date` if absent.
> - `last_processed:` or `last_sync:` — the cursor value. For `kind: date`, must be `YYYY-MM-DD` or null. For `kind: opaque`, may be any string or null.
>
> If both `last_processed:` and `last_sync:` are absent or null, the manifest is treated as "never processed" regardless of `kind`. For `kind: opaque` with a non-null value, the tool treats the cursor as **fresh** and does not compute an age (the producing skill owns currency).

- [ ] **Step 2: Edit "Check definitions / 5. Stale manifests" to reflect the kind matrix above.**

- [ ] **Step 3: Edit "JSON output shapes / `check`" — `stale_manifests` items**, splitting `cursor_kind` and `cursor_field`:

```json
{
  "file": "claude-chat.yml",
  "cursor_kind": "date",
  "cursor_field": "last_sync",
  "value": null,
  "age_days": null
}
```

- [ ] **Step 4: Edit "JSON output shapes / `manifests`"** with the same split.

- [ ] **Step 5: Add a "Versioning / Breaking changes" note** documenting the v0.2.0 bump:

> **0.2.0 (2026-05-13)**: Manifest cursor JSON shape gained a `cursor_field` key; `cursor_kind` now reports the cursor `kind:` discriminator (`"date"` | `"opaque"`) instead of the cursor field name. Consumers parsing manifest JSON output must update accordingly.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-05-05-esper-lint-design.md
git -c user.name='Mike Subelsky' -c user.email='12020+subelsky@users.noreply.github.com' \
  commit -m "spec: manifest cursor 'kind' discriminator (date vs opaque) for esper-lint v0.2.0"
```

---

### Task 2: esper-lint code changes (tools repo)

**Files (in the user's tools project, not Synergy):**
- `lib/esper_lint/parsing.rb`
- `lib/esper_lint/checks.rb`
- `lib/esper_lint/queries.rb`
- `lib/esper_lint/version.rb`
- `test/fixtures/esper/sources/manifest-opaque.yml` (new)
- `test/fixtures/esper/sources/manifest-fresh.yml` (modify — add `kind: date`)
- `test/fixtures/esper/sources/manifest-stale.yml` (modify — add `kind: date`)
- `test/test_parsing.rb`
- `test/test_checks.rb`
- `test/test_queries.rb`

- [ ] **Step 1: Write failing tests in `test/test_parsing.rb`.**

```ruby
def test_parse_manifest_cursor_recognizes_kind_date
  text = "cursor:\n  kind: date\n  last_processed: 2026-04-12\n"
  cursor = EsperLint::Parsing.parse_manifest_cursor(text)
  assert_equal :date, cursor[:kind]
  assert_equal :last_processed, cursor[:cursor_field]
  assert_equal Date.new(2026, 4, 12), cursor[:value]
end

def test_parse_manifest_cursor_recognizes_kind_opaque
  text = "cursor:\n  kind: opaque\n  last_processed: zakelfassi.com_2cfea35833e8\n"
  cursor = EsperLint::Parsing.parse_manifest_cursor(text)
  assert_equal :opaque, cursor[:kind]
  assert_equal :last_processed, cursor[:cursor_field]
  assert_equal "zakelfassi.com_2cfea35833e8", cursor[:value]
end

def test_parse_manifest_cursor_defaults_kind_to_date_when_absent
  text = "cursor:\n  last_processed: 2026-04-12\n"
  cursor = EsperLint::Parsing.parse_manifest_cursor(text)
  assert_equal :date, cursor[:kind]
  assert_equal Date.new(2026, 4, 12), cursor[:value]
end

def test_parse_manifest_cursor_opaque_with_unparseable_value_does_not_warn
  text = "cursor:\n  kind: opaque\n  last_processed: any-string-here\n"
  _out, err = capture_subprocess_io do
    EsperLint::Parsing.parse_manifest_cursor(text)
  end
  refute_includes err, "unparseable_cursor_date"
end

def test_parse_manifest_cursor_date_with_unparseable_value_warns
  text = "cursor:\n  kind: date\n  last_processed: not-a-date\n"
  _out, err = capture_subprocess_io do
    EsperLint::Parsing.parse_manifest_cursor(text)
  end
  assert_includes err, "unparseable_cursor_date"
end
```

Run: `bundle exec ruby -Ilib -Itest test/test_parsing.rb`. Expect failures.

- [ ] **Step 2: Update `Parsing.parse_manifest_cursor`** in `lib/esper_lint/parsing.rb`.

The new return shape: `{ kind: :date | :opaque, cursor_field: :last_processed | :last_sync | nil, value: Date | String | nil }`.

```ruby
def self.parse_manifest_cursor(text)
  data = YAML.safe_load(text, permitted_classes: [Date, Time, Symbol]) || {}
  cursor_block = data["cursor"]
  return {kind: :date, cursor_field: nil, value: nil} unless cursor_block.is_a?(Hash)

  kind = (cursor_block["kind"] || "date").to_sym
  field = if cursor_block.key?("last_processed")
    :last_processed
  elsif cursor_block.key?("last_sync")
    :last_sync
  end
  raw = field ? cursor_block[field.to_s] : nil

  value = case kind
  when :opaque
    raw.nil? ? nil : raw.to_s
  when :date
    coerce_cursor_date(raw)
  end

  {kind: kind, cursor_field: field, value: value}
end
```

(Note `coerce_cursor_date` is the existing helper — keep its current warn-on-failure behavior. The opaque path bypasses it entirely so no warning is emitted.)

- [ ] **Step 3: Run parsing tests; expect green.**

- [ ] **Step 4: Update fixtures.**

`test/fixtures/esper/sources/manifest-fresh.yml`:
```yaml
source_type: example
cursor:
  kind: date
  last_processed: 2026-05-01
```

`test/fixtures/esper/sources/manifest-stale.yml`:
```yaml
source_type: example
cursor:
  kind: date
  last_sync: null
```

`test/fixtures/esper/sources/manifest-opaque.yml` (new):
```yaml
source_type: filesystem-walk-example
cursor:
  kind: opaque
  last_processed: somesite.com_abc123def
```

- [ ] **Step 5: Write failing tests in `test/test_checks.rb`.**

```ruby
def test_stale_manifests_treats_opaque_with_value_as_fresh
  result = EsperLint::Checks.stale_manifests(repo, stale_days: 30, today: Date.new(2026, 5, 5))
  files = result[:items].map { |i| i[:file] }
  refute_includes files, "manifest-opaque.yml"
end

def test_stale_manifests_emits_cursor_kind_and_cursor_field
  result = EsperLint::Checks.stale_manifests(repo, stale_days: 1, today: Date.new(2026, 5, 5))
  fresh_item = result[:items].find { |i| i[:file] == "manifest-fresh.yml" }
  refute_nil fresh_item
  assert_equal "date", fresh_item[:cursor_kind]
  assert_equal "last_processed", fresh_item[:cursor_field]
end
```

- [ ] **Step 6: Update `Checks.stale_manifests`** in `lib/esper_lint/checks.rb`:

```ruby
def stale_manifests(repo, stale_days:, today: Date.today)
  items = repo.manifests.filter_map do |m|
    cursor = m.cursor
    is_stale, age_days = classify_manifest_staleness(cursor, stale_days, today)
    next unless is_stale

    {
      file: m.filename,
      cursor_kind: cursor[:kind].to_s,
      cursor_field: cursor[:cursor_field]&.to_s,
      value: cursor[:value].is_a?(Date) ? cursor[:value].to_s : cursor[:value],
      age_days: age_days,
      is_stale: true
    }
  end
  {total: items.size, stale_days_threshold: stale_days, items: items.sort_by { |i| i[:file] }}
end

def classify_manifest_staleness(cursor, stale_days, today)
  case cursor[:kind]
  when :opaque
    cursor[:value].nil? ? [true, nil] : [false, nil]
  when :date
    if cursor[:value].nil?
      [true, nil]
    else
      age = (today - cursor[:value]).to_i
      [age >= stale_days, age]
    end
  else
    [true, nil]
  end
end
module_function :classify_manifest_staleness
```

- [ ] **Step 7: Run check tests; expect green.**

- [ ] **Step 8: Update `Queries.manifests`** in `lib/esper_lint/queries.rb` to emit the same shape (`cursor_kind`, `cursor_field`, `value`, `age_days`, `is_stale`) and to honor the opaque-is-fresh rule. Mirror the logic from `Checks.stale_manifests`.

Add a test in `test/test_queries.rb` asserting that `Queries.manifests(repo, stale: true)` excludes the opaque fixture and that the output includes both `cursor_kind` and `cursor_field` keys.

- [ ] **Step 9: Run full test suite.**

```bash
bundle exec rake
```

Expect green. Standardrb must also pass.

- [ ] **Step 10: Bump version** in `lib/esper_lint/version.rb`:

```ruby
module EsperLint
  VERSION = "0.2.0"
end
```

- [ ] **Step 11: Update CLI help text** in `lib/esper_lint/cli.rb` if it lists manifest-related output keys explicitly. The error code table doesn't change.

- [ ] **Step 12: Commit (in tools repo).**

```bash
git add -A
git -c user.name='Mike Subelsky' -c user.email='12020+subelsky@users.noreply.github.com' \
  commit -m "feat: manifest cursor kind discriminator (date vs opaque); v0.2.0

Adds 'kind:' field to manifest cursor parsing. opaque cursors with non-null
values are treated as fresh (the producing skill owns currency). date cursors
behave as before. Backward compatible: kind defaults to :date when absent.

JSON output: stale_manifests/manifests items now include both 'cursor_kind'
(date|opaque, the discriminator) and 'cursor_field' (last_processed|last_sync,
the field name). Breaking change → 0.2.0."
```

- [ ] **Step 13: Tag the release.**

```bash
git tag v0.2.0
```

---

### Task 3: Update integrate skill

**Files:**
- `.claude/commands/integrate.md`

The integrate skill writes new cursor values when it advances a manifest. After this change, it should also write the `kind:` field.

- [ ] **Step 1: Read `.claude/commands/integrate.md`** and find every place the skill describes writing cursor values.

- [ ] **Step 2: Add a section on cursor kind:**

> **Manifest cursor format**: every manifest's `cursor:` block must include a `kind:` field. Two values:
>
> - `kind: date` — for time-ordered sources (Readwise, research papers, etc.). The cursor value is `YYYY-MM-DD`.
> - `kind: opaque` — for filesystem-walked sources where the cursor is a position pointer (slug, hash, offset). esper-lint will not parse these as dates.
>
> When advancing a cursor, preserve the existing `kind:` value. When creating a new manifest, choose `kind:` based on the source's iteration model and document the choice in the manifest comments.

- [ ] **Step 3: Update any integrate-skill code blocks that show cursor format** to include `kind:`.

- [ ] **Step 4: Commit (in Synergy).**

```bash
git add .claude/commands/integrate.md
git -c user.name='Mike Subelsky' -c user.email='12020+subelsky@users.noreply.github.com' \
  commit -m "skill: integrate writes manifest cursor 'kind' field (date|opaque)"
```

---

### Task 4: Migrate existing manifests

**Files:**
- `esper/sources/instapaper.yaml`
- `esper/sources/readwise.yml`
- `esper/sources/research-papers.yml`
- `esper/sources/claude-chat.yml`
- `esper/sources/claude-code.yml`
- `esper/sources/email.yml`
- `esper/sources/things3.yml`
- `esper/sources/git-repos.yml`

Each manifest gets `kind:` added inside its `cursor:` block.

- [ ] **Step 1: Edit each manifest.** For the 7 time-ordered ones, add `kind: date`. For `instapaper.yaml`, add `kind: opaque`.

Pattern for date manifests:
```yaml
cursor:
  kind: date           # ADD this line
  last_processed: 2026-04-12
```

Pattern for instapaper:
```yaml
cursor:
  kind: opaque         # ADD this line
  last_processed: zakelfassi.com_2cfea35833e8
```

For manifests with no `cursor.last_processed` or `cursor.last_sync` (like `git-repos.yml`), add the `kind:` field too:
```yaml
cursor:
  kind: date           # ADD this line
```

- [ ] **Step 2: Verify with esper-lint v0.2.0:**

```bash
cd /Users/subelsky/Synergy
bin/esper-lint manifests --stale --esper-dir esper | jq '.results[] | {file, cursor_kind, value, is_stale}'
```

Expect:
- `instapaper.yaml` is NOT in the output (opaque + non-null = fresh).
- `claude-chat.yml`, `claude-code.yml`, `email.yml`, `things3.yml`, `git-repos.yml` still appear (date + null = stale).
- `readwise.yml` and `research-papers.yml` may or may not appear depending on `--stale-days` and their dates.

Also run `bin/esper-lint check --esper-dir esper 2>/tmp/warn.log` and verify `/tmp/warn.log` no longer contains the `unparseable_cursor_date` warning.

- [ ] **Step 3: Commit (in esper repo, since esper has its own git).**

```bash
cd /Users/subelsky/Synergy/esper
git add sources/*.yml sources/*.yaml
git -c user.name='Mike Subelsky' -c user.email='12020+subelsky@users.noreply.github.com' \
  commit -m "data: add cursor kind discriminator to all source manifests

instapaper.yaml uses kind: opaque (filesystem-walk cursor); all others
use kind: date. Aligned with esper-lint v0.2.0 schema."
```

---

### Task 5: Update esper skill caveat

**Files:**
- `.claude/commands/esper.md`

The "Known caveats" section currently warns about the `instapaper.yaml` slug-cursor case. After Tasks 1-4 land, that caveat is obsolete.

- [ ] **Step 1: Remove the caveat block** about `instapaper.yaml`. Replace with a one-line note in the lint protocol that opaque-kind manifests are treated as fresh by design.

- [ ] **Step 2: Commit.**

```bash
git add .claude/commands/esper.md
git -c user.name='Mike Subelsky' -c user.email='12020+subelsky@users.noreply.github.com' \
  commit -m "skill: drop instapaper.yaml cursor caveat (resolved by esper-lint v0.2.0)"
```

---

## Order of execution

Tasks are mostly independent but have a sensible execution order:

1. **Task 1** (spec edit) — locks the contract
2. **Task 2** (esper-lint code + version bump) — implements the contract
3. **Task 4** (manifest migration) — requires v0.2.0 deployed for verification
4. **Task 3** (integrate skill update) — can happen in parallel with 2/4
5. **Task 5** (esper skill caveat removal) — last, after verification

Each task ends in a commit; nothing should be left dangling.

## Verification — definition of done

After all 5 tasks land:

```bash
cd /Users/subelsky/Synergy
bin/esper-lint version          # → "esper-lint 0.2.0"
bin/esper-lint check --esper-dir esper 2>/tmp/warn.log
grep unparseable_cursor_date /tmp/warn.log    # → no output
bin/esper-lint manifests --stale --esper-dir esper | \
  jq '.results | map(.file)'    # → does NOT include instapaper.yaml
```

All three should pass cleanly.
