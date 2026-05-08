# esper-lint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Ruby CLI toolkit (`esper-lint`) that gives Claude deterministic data-gathering and safe-fix primitives for the Esper knowledge base, replacing inline grep/awk/sed/python scripts.

**Architecture:** Single Ruby file (split across small focused modules under `lib/esper_lint/`), pure stdlib (`optparse`, `yaml`, `json`, `pathname`, `date`, `open3`). Eager-loads the esper directory once per invocation (max ~2200 source files). One module per concern: parsing, repo, checks, queries, fixes, mutations, git, cli. JSON-only output. Tests with stdlib `minitest` against a tiny fixture esper directory under `test/fixtures/esper/`.

**Tech Stack:** Ruby (3.x), stdlib only at runtime, `standard` gem (Standard Ruby) at dev time, `minitest` (stdlib).

**Reference spec:** `docs/superpowers/specs/2026-05-05-esper-lint-design.md` (Synergy repo). The agent implementing this should read the spec first; this plan implements that spec exactly.

**Working directory:** This project lives in the user's `tools` repo, not in Synergy. The implementer creates a new top-level directory `esper-lint/` (or whatever the tools repo conventions dictate). All file paths in this plan are relative to that project root unless prefixed with `synergy:`.

---

## File Structure

```
esper-lint/
├── .gitignore
├── Gemfile
├── Gemfile.lock
├── README.md
├── Rakefile
├── bin/
│   └── esper-lint                 # Executable shim, ~3 lines
├── lib/
│   ├── esper_lint.rb              # Top-level require shim
│   └── esper_lint/
│       ├── version.rb             # VERSION constant
│       ├── error.rb               # EsperLint::Error (code, path, details)
│       ├── parsing.rb             # Pure functions: frontmatter/sources/L0/manifest/index parsers
│       ├── repo.rb                # EsperRepo: eager-loads + caches everything from disk
│       ├── checks.rb              # 7 lint checks, one method each
│       ├── queries.rb             # Parameterized read methods
│       ├── fixes.rb               # 3 safe fixes
│       ├── mutations.rb           # add_source
│       ├── git.rb                 # working_tree_clean? via Open3
│       └── cli.rb                 # OptionParser dispatch + JSON serialization
└── test/
    ├── test_helper.rb
    ├── fixtures/
    │   └── esper/                 # Tiny replica covering all edge cases
    ├── test_parsing.rb
    ├── test_repo.rb
    ├── test_checks.rb
    ├── test_queries.rb
    ├── test_fixes.rb
    ├── test_mutations.rb
    ├── test_git.rb
    └── test_cli.rb
```

**Module responsibility recap (from spec):**
- `Parsing` — pure functions, no I/O
- `Repo` — eager loader, single source of truth
- `Checks` — one method per lint check, takes a `Repo`, returns the JSON-shaped hash for that check
- `Queries` — parameterized filters
- `Fixes` — mutates files, returns "applied" hash
- `Mutations` — `add_source` (the only single-purpose mutation in v1)
- `Git` — clean-tree check
- `CLI` — `OptionParser` dispatch, JSON to stdout, error envelope to stderr, exit code mapping

---

## Task 1: Project skeleton

**Files:**
- Create: `Gemfile`
- Create: `.gitignore`
- Create: `lib/esper_lint.rb`
- Create: `lib/esper_lint/version.rb`
- Create: `bin/esper-lint`
- Create: `Rakefile`
- Create: `README.md`
- Create: `test/test_helper.rb`

- [ ] **Step 1: Initialize git and create `.gitignore`**

```bash
mkdir -p esper-lint && cd esper-lint
git init
```

`.gitignore`:
```
*.gem
.bundle/
Gemfile.lock
coverage/
tmp/
.DS_Store
```

- [ ] **Step 2: Create `Gemfile`**

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

group :development do
  gem "standard"
  gem "rake"
end
```

- [ ] **Step 3: Run `bundle install`**

```bash
bundle install
```

Expected: installs `standard` and `rake` and their deps.

- [ ] **Step 4: Create `lib/esper_lint/version.rb`**

```ruby
# frozen_string_literal: true

module EsperLint
  VERSION = "0.1.0"
end
```

- [ ] **Step 5: Create `lib/esper_lint.rb` (top-level require shim)**

```ruby
# frozen_string_literal: true

require_relative "esper_lint/version"
require_relative "esper_lint/error"
require_relative "esper_lint/parsing"
require_relative "esper_lint/repo"
require_relative "esper_lint/checks"
require_relative "esper_lint/queries"
require_relative "esper_lint/fixes"
require_relative "esper_lint/mutations"
require_relative "esper_lint/git"
require_relative "esper_lint/cli"

module EsperLint
end
```

(Yes, this requires modules that don't exist yet. We'll create empty stubs in Task 2 so this loads.)

- [ ] **Step 6: Create empty stub files for each lib module**

For each of `error.rb`, `parsing.rb`, `repo.rb`, `checks.rb`, `queries.rb`, `fixes.rb`, `mutations.rb`, `git.rb`, `cli.rb`:

```ruby
# frozen_string_literal: true

module EsperLint
  module ModuleName  # replace with actual name
  end
end
```

`error.rb` is special:

```ruby
# frozen_string_literal: true

module EsperLint
  class Error < StandardError
    attr_reader :code, :path, :details

    def initialize(code:, message:, path: nil, details: {})
      super(message)
      @code = code
      @path = path
      @details = details
    end
  end
end
```

- [ ] **Step 7: Create `bin/esper-lint`**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/esper_lint"

exit EsperLint::CLI.run(ARGV)
```

```bash
chmod +x bin/esper-lint
```

- [ ] **Step 8: Add a stub `CLI.run` so the binary doesn't crash**

In `lib/esper_lint/cli.rb`:

```ruby
# frozen_string_literal: true

module EsperLint
  module CLI
    def self.run(argv)
      warn "esper-lint v#{EsperLint::VERSION} — not yet implemented"
      0
    end
  end
end
```

- [ ] **Step 9: Verify the binary loads and runs**

```bash
ruby -Ilib bin/esper-lint
```

Expected: prints `esper-lint v0.1.0 — not yet implemented` to stderr, exits 0.

- [ ] **Step 10: Create `test/test_helper.rb`**

```ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "esper_lint"

FIXTURE_ROOT = File.expand_path("fixtures/esper", __dir__)
```

- [ ] **Step 11: Create `Rakefile`**

```ruby
# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib" << "test"
  t.test_files = FileList["test/test_*.rb"]
  t.warning = false
end

require "standard/rake"

task default: %i[test standard]
```

- [ ] **Step 12: Create `README.md`**

A minimal README — installation, usage examples for each subcommand, link to spec. Keep it under 100 lines for v1.

```markdown
# esper-lint

Ruby CLI toolkit for the [Esper knowledge base](https://github.com/...). Provides deterministic lint, safe fixes, and query/mutation primitives so orchestrators (e.g. Claude) can stop writing inline bash/awk/sed/python.

See `docs/superpowers/specs/2026-05-05-esper-lint-design.md` in the Synergy repo for the design spec.

## Install

\`\`\`
bundle install
\`\`\`

## Usage

\`\`\`
bin/esper-lint check                    # full lint, JSON to stdout
bin/esper-lint fix                      # apply the 3 safe fixes (requires clean git tree)
bin/esper-lint sources --orphan         # list orphans
bin/esper-lint tags --threshold 3 --missing-page
bin/esper-lint add-source TOPIC SOURCE
\`\`\`

Run \`bin/esper-lint help\` for the full subcommand list.

## Test

\`\`\`
bundle exec rake test
\`\`\`

## Lint

\`\`\`
bundle exec standardrb
\`\`\`
```

- [ ] **Step 13: Verify `rake` runs (will pass with no tests yet)**

```bash
bundle exec rake test
```

Expected: `0 runs, 0 assertions, 0 failures, 0 errors, 0 skips`.

- [ ] **Step 14: Verify `standardrb` runs cleanly**

```bash
bundle exec standardrb
```

Expected: passes (or auto-fix what it complains about with `bundle exec standardrb --fix`).

- [ ] **Step 15: Commit**

```bash
git add -A
git commit -m "feat: project skeleton with Gemfile, version, stub lib modules, bin shim, Rakefile"
```

---

## Task 2: Test fixture esper directory

**Files:**
- Create: `test/fixtures/esper/index.md`
- Create: `test/fixtures/esper/pages/topics/*.md` (6 topic pages)
- Create: `test/fixtures/esper/pages/sources/*.md` (12 source pages)
- Create: `test/fixtures/esper/sources/*.yml` (2 manifests)

The fixture must cover every edge case mentioned in the spec. This is the foundation of all later tests.

- [ ] **Step 1: Create `test/fixtures/esper/pages/topics/topic-clean.md`**

```markdown
<!-- L0: Clean topic — well-formed, source_count matches actual links -->
---
created: 2026-04-01
source_count: 2
---

# Clean Topic

## Current Synthesis
Synthesis prose.

## Sources
- [[pages/sources/source-tagged-topic-clean]]
- [[pages/sources/source-unicode-éàü]]

## Connections
- [[pages/topics/topic-mismatch]] — related
```

- [ ] **Step 2: Create `topic-mismatch.md` (frontmatter source_count drifts from actual)**

```markdown
<!-- L0: Mismatch topic — frontmatter says 5, actually has 1 link -->
---
created: 2026-04-01
source_count: 5
---

# Mismatch Topic

## Current Synthesis
Synthesis prose.

## Sources
- [[pages/sources/source-tagged-topic-mismatch]]

## Connections
- [[pages/topics/topic-clean]] — related
```

- [ ] **Step 3: Create `topic-no-connections.md`**

```markdown
<!-- L0: No connections — missing the Connections section -->
---
created: 2026-04-01
source_count: 1
---

# No Connections Topic

## Current Synthesis
Synthesis prose.

## Sources
- [[pages/sources/source-tagged-topic-no-connections]]
```

- [ ] **Step 4: Create `topic-duplicate-sources.md`**

```markdown
<!-- L0: Duplicate sources — same slug appears twice -->
---
created: 2026-04-01
source_count: 2
---

# Duplicate Sources Topic

## Current Synthesis
Synthesis prose.

## Sources
- [[pages/sources/source-stub]]
- [[pages/sources/source-stub]]

## Connections
- [[pages/topics/topic-clean]] — related
```

(Note: `source_count: 2` but only 1 unique source — this also creates a count mismatch when dedup'd, exercising the "fix runs in correct order" path.)

- [ ] **Step 5: Create `topic-empty.md`**

```markdown
<!-- L0: Empty topic — zero sources, valid -->
---
created: 2026-04-01
source_count: 0
---

# Empty Topic

## Current Synthesis
A new topic with no sources yet.

## Sources

## Connections
- [[pages/topics/topic-clean]] — related
```

- [ ] **Step 6: Create `topic-with-tag-shared.md`** (the topic that the "fixable orphan" source's tag points to)

```markdown
<!-- L0: Shared-tag topic — fixable orphans point here via their topics: array -->
---
created: 2026-04-01
source_count: 1
---

# Shared Tag Topic

## Current Synthesis
Synthesis prose.

## Sources
- [[pages/sources/source-tagged-topic-with-tag-shared]]

## Connections
- [[pages/topics/topic-clean]] — related
```

- [ ] **Step 7: Create source pages** under `test/fixtures/esper/pages/sources/`. One file per source listed below; bodies can be minimal.

Each source page has YAML frontmatter and a body. Use this template, varying the slug and `topics:`:

```markdown
---
source_type: instapaper-article
source_file: "example.com/foo.md"
title: "Example title"
ingested: 2026-04-01
topics: [TAGS_HERE]
---

# Example title

## Key Takeaways
- Example takeaway.
```

Files to create:

| Slug (filename without .md) | `topics:` | Notes |
|---|---|---|
| `source-tagged-topic-clean` | `[topic-clean]` | Linked from topic-clean (not orphan) |
| `source-tagged-topic-mismatch` | `[topic-mismatch]` | Linked from topic-mismatch |
| `source-tagged-topic-no-connections` | `[topic-no-connections]` | Linked from topic-no-connections |
| `source-tagged-topic-with-tag-shared` | `[topic-with-tag-shared]` | Linked from topic-with-tag-shared |
| `source-unicode-éàü` | `[topic-clean]` | Unicode chars in slug, linked from topic-clean |
| `source-stub` | `[]` | Empty topics — stub orphan |
| `source-stub-twin-9359a1` | `[]` | Hash-suffix collision twin (also empty) |
| `source-fixable-orphan` | `[topic-with-tag-shared]` | Tagged with an existing topic, but NOT linked from any topic page → fixable orphan |
| `source-subthreshold-orphan` | `[unique-tag-only]` | Tagged but tag has no topic page → subthreshold orphan |
| `source-shared-tag-1` | `[shared-missing-tag]` | One of three sources sharing a missing-topic candidate tag |
| `source-shared-tag-2` | `[shared-missing-tag]` | Second of three |
| `source-shared-tag-3` | `[shared-missing-tag]` | Third of three — pushes `shared-missing-tag` to threshold of 3 |

(`shared-missing-tag` will be the missing-topic candidate; `unique-tag-only` will be a 1-occurrence subthreshold tag.)

Verify file count:

```bash
ls test/fixtures/esper/pages/sources/ | wc -l
```

Expected: `12`.

- [ ] **Step 8: Create source manifests** under `test/fixtures/esper/sources/`

`test/fixtures/esper/sources/manifest-fresh.yml`:
```yaml
source_type: example
cursor:
  last_processed: 2026-05-01
```

`test/fixtures/esper/sources/manifest-stale.yml`:
```yaml
source_type: example
cursor:
  last_sync: null
```

- [ ] **Step 9: Create `test/fixtures/esper/index.md`**

```markdown
<!-- L0: Two-tier topic index — entry point for all Esper queries -->
# Esper Index

## Topics

| Topic | Sources | Last Updated | Summary |
|-------|---------|--------------|---------|
| [[pages/topics/topic-mismatch]] | 5 | 2026-04-01 | Mismatch topic — frontmatter says 5, actually has 1 link |
| [[pages/topics/topic-clean]] | 2 | 2026-04-01 | Clean topic — well-formed, source_count matches actual links |
| [[pages/topics/topic-duplicate-sources]] | 2 | 2026-04-01 | Duplicate sources — same slug appears twice |
| [[pages/topics/topic-no-connections]] | 1 | 2026-04-01 | No connections — missing the Connections section |
| [[pages/topics/topic-with-tag-shared]] | 1 | 2026-04-01 | Shared-tag topic — fixable orphans point here via their topics: array |
| [[pages/topics/topic-empty]] | 0 | 2026-04-01 | Empty topic — zero sources, valid |
```

(The index is intentionally consistent with disk EXCEPT that `topic-mismatch` shows 5 in the index too — this exercises the "rebuild fixes both index and frontmatter" path.)

- [ ] **Step 10: Commit the fixture**

```bash
git add test/fixtures/
git commit -m "test: fixture esper directory covering all edge cases"
```

---

## Task 3: Parsing — frontmatter, L0, sources, topics array

**Files:**
- Modify: `lib/esper_lint/parsing.rb`
- Create: `test/test_parsing.rb`

`Parsing` is pure functions, no I/O. The caller passes file contents (a String) in, gets data out.

**Methods to implement:**
- `Parsing.parse_frontmatter(text) → Hash` (uses `YAML.safe_load`; returns empty hash if no frontmatter; raises `EsperLint::Error(code: MALFORMED_FRONTMATTER)` on YAML parse failure)
- `Parsing.extract_l0(text) → String | nil` (matches `\A<!--\s*L0:\s*(.*?)\s*-->\s*\z` against line 1 only)
- `Parsing.extract_sources(text) → Array<String>` (returns slugs found in `^- \[\[pages/sources/(.+?)\]\]` lines within the `## Sources` section, in document order)
- `Parsing.extract_topics_array(frontmatter_hash) → Array<String>` (returns the `topics:` value as a normalized array of strings; `[]` if absent or nil)

- [ ] **Step 1: Write failing tests in `test/test_parsing.rb`**

```ruby
# frozen_string_literal: true

require_relative "test_helper"

class TestParsing < Minitest::Test
  def topic_clean
    File.read(File.join(FIXTURE_ROOT, "pages/topics/topic-clean.md"))
  end

  def topic_no_connections
    File.read(File.join(FIXTURE_ROOT, "pages/topics/topic-no-connections.md"))
  end

  def source_unicode
    File.read(File.join(FIXTURE_ROOT, "pages/sources/source-unicode-éàü.md"))
  end

  def source_stub
    File.read(File.join(FIXTURE_ROOT, "pages/sources/source-stub.md"))
  end

  def test_parse_frontmatter_returns_hash
    fm = EsperLint::Parsing.parse_frontmatter(topic_clean)
    assert_equal 2, fm["source_count"]
    assert_equal "2026-04-01", fm["created"].to_s
  end

  def test_parse_frontmatter_returns_empty_hash_when_no_frontmatter
    assert_equal({}, EsperLint::Parsing.parse_frontmatter("just a body"))
  end

  def test_parse_frontmatter_raises_on_malformed_yaml
    bad = "---\nfoo: : bar\n---\nbody"
    err = assert_raises(EsperLint::Error) { EsperLint::Parsing.parse_frontmatter(bad) }
    assert_equal :MALFORMED_FRONTMATTER, err.code
  end

  def test_extract_l0_matches_line_1
    assert_equal "Clean topic — well-formed, source_count matches actual links",
      EsperLint::Parsing.extract_l0(topic_clean)
  end

  def test_extract_l0_returns_nil_when_absent
    assert_nil EsperLint::Parsing.extract_l0("# No L0 here")
  end

  def test_extract_l0_only_matches_line_1
    text = "# Title\n<!-- L0: not a real L0 -->\n"
    assert_nil EsperLint::Parsing.extract_l0(text)
  end

  def test_extract_sources_returns_slugs_in_order
    slugs = EsperLint::Parsing.extract_sources(topic_clean)
    assert_equal ["source-tagged-topic-clean", "source-unicode-éàü"], slugs
  end

  def test_extract_sources_handles_unicode
    slugs = EsperLint::Parsing.extract_sources(topic_clean)
    assert_includes slugs, "source-unicode-éàü"
  end

  def test_extract_sources_returns_empty_for_no_sources_section
    assert_equal [], EsperLint::Parsing.extract_sources("# Title\n\nNo sources section here.")
  end

  def test_extract_topics_array_returns_strings
    fm = EsperLint::Parsing.parse_frontmatter(source_unicode)
    assert_equal ["topic-clean"], EsperLint::Parsing.extract_topics_array(fm)
  end

  def test_extract_topics_array_returns_empty_for_stub
    fm = EsperLint::Parsing.parse_frontmatter(source_stub)
    assert_equal [], EsperLint::Parsing.extract_topics_array(fm)
  end

  def test_extract_topics_array_returns_empty_when_topics_missing
    assert_equal [], EsperLint::Parsing.extract_topics_array({})
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec ruby -Ilib -Itest test/test_parsing.rb
```

Expected: 11 failures/errors (no methods defined yet).

- [ ] **Step 3: Implement `lib/esper_lint/parsing.rb`**

```ruby
# frozen_string_literal: true

require "yaml"

module EsperLint
  module Parsing
    FRONTMATTER_RE = /\A---\s*\n(.*?)\n---\s*\n?/m
    L0_RE = /\A<!--\s*L0:\s*(.*?)\s*-->\s*\z/
    SOURCE_LINK_RE = /^-\s*\[\[pages\/sources\/(.+?)\]\]\s*$/

    module_function

    def parse_frontmatter(text)
      m = FRONTMATTER_RE.match(text)
      return {} unless m

      YAML.safe_load(m[1], permitted_classes: [Date, Time, Symbol]) || {}
    rescue Psych::SyntaxError => e
      raise EsperLint::Error.new(
        code: :MALFORMED_FRONTMATTER,
        message: "YAML parse failed: #{e.message}"
      )
    end

    def extract_l0(text)
      first_line = text.each_line.first
      return nil unless first_line

      m = L0_RE.match(first_line.chomp)
      m && m[1]
    end

    def extract_sources(text)
      in_sources = false
      slugs = []
      text.each_line do |line|
        stripped = line.rstrip
        if stripped == "## Sources"
          in_sources = true
          next
        end
        if in_sources && stripped.start_with?("## ")
          break
        end
        next unless in_sources

        m = SOURCE_LINK_RE.match(stripped)
        slugs << m[1] if m
      end
      slugs
    end

    def extract_topics_array(frontmatter_hash)
      raw = frontmatter_hash["topics"]
      return [] if raw.nil?

      Array(raw).map(&:to_s)
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec ruby -Ilib -Itest test/test_parsing.rb
```

Expected: 11 runs, all passing.

- [ ] **Step 5: Run standardrb and fix any style issues**

```bash
bundle exec standardrb --fix lib/esper_lint/parsing.rb test/test_parsing.rb
```

- [ ] **Step 6: Commit**

```bash
git add lib/esper_lint/parsing.rb test/test_parsing.rb
git commit -m "feat: Parsing module — frontmatter, L0, sources, topics array (TDD)"
```

---

## Task 4: Parsing — manifest cursor, index table

**Files:**
- Modify: `lib/esper_lint/parsing.rb`
- Modify: `test/test_parsing.rb`

**Methods to add:**
- `Parsing.parse_manifest_cursor(text) → { kind: :last_processed | :last_sync | nil, value: Date | nil }` — reads the top-level `cursor:` block, prefers `last_processed` over `last_sync` if both present
- `Parsing.parse_index_table(text) → Array<{ slug:, count:, date:, summary:, raw_line: }>` — parses recognized rows; rows that don't match the format are not returned (caller can detect drift)

- [ ] **Step 1: Write failing tests**

Append to `test/test_parsing.rb`:

```ruby
  def index_text
    File.read(File.join(FIXTURE_ROOT, "index.md"))
  end

  def manifest_fresh
    File.read(File.join(FIXTURE_ROOT, "sources/manifest-fresh.yml"))
  end

  def manifest_stale
    File.read(File.join(FIXTURE_ROOT, "sources/manifest-stale.yml"))
  end

  def test_parse_manifest_cursor_returns_date_for_last_processed
    cursor = EsperLint::Parsing.parse_manifest_cursor(manifest_fresh)
    assert_equal :last_processed, cursor[:kind]
    assert_equal Date.new(2026, 5, 1), cursor[:value]
  end

  def test_parse_manifest_cursor_returns_nil_value_for_null_cursor
    cursor = EsperLint::Parsing.parse_manifest_cursor(manifest_stale)
    assert_equal :last_sync, cursor[:kind]
    assert_nil cursor[:value]
  end

  def test_parse_manifest_cursor_returns_nil_kind_when_no_cursor_block
    cursor = EsperLint::Parsing.parse_manifest_cursor("source_type: foo\n")
    assert_nil cursor[:kind]
    assert_nil cursor[:value]
  end

  def test_parse_index_table_returns_rows
    rows = EsperLint::Parsing.parse_index_table(index_text)
    assert_equal 6, rows.size
    first = rows.first
    assert_equal "topic-mismatch", first[:slug]
    assert_equal 5, first[:count]
    assert_equal "2026-04-01", first[:date]
    assert_includes first[:summary], "Mismatch topic"
  end

  def test_parse_index_table_ignores_non_matching_rows
    text = "| garbage | row |\n| [[pages/topics/foo]] | 1 | 2026-01-01 | bar |\n"
    rows = EsperLint::Parsing.parse_index_table(text)
    assert_equal 1, rows.size
    assert_equal "foo", rows.first[:slug]
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec ruby -Ilib -Itest test/test_parsing.rb
```

Expected: 5 new failures/errors.

- [ ] **Step 3: Implement the new methods in `lib/esper_lint/parsing.rb`**

Add inside the `Parsing` module:

```ruby
require "date"

# ...

INDEX_ROW_RE = /^\|\s*\[\[pages\/topics\/([^\]]+)\]\]\s*\|\s*(\d+)\s*\|\s*([\d-]+)\s*\|\s*(.*?)\s*\|\s*$/

def self.parse_manifest_cursor(text)
  data = YAML.safe_load(text, permitted_classes: [Date, Time, Symbol]) || {}
  cursor_block = data["cursor"]
  return {kind: nil, value: nil} unless cursor_block.is_a?(Hash)

  if cursor_block.key?("last_processed")
    {kind: :last_processed, value: cursor_block["last_processed"]}
  elsif cursor_block.key?("last_sync")
    {kind: :last_sync, value: cursor_block["last_sync"]}
  else
    {kind: nil, value: nil}
  end
end

def self.parse_index_table(text)
  rows = []
  text.each_line do |line|
    m = INDEX_ROW_RE.match(line)
    next unless m

    rows << {
      slug: m[1],
      count: m[2].to_i,
      date: m[3],
      summary: m[4],
      raw_line: line.chomp
    }
  end
  rows
end
```

(Make sure `require "date"` is at the top of the file, after `require "yaml"`.)

- [ ] **Step 4: Run tests to verify they pass**

```bash
bundle exec ruby -Ilib -Itest test/test_parsing.rb
```

Expected: 16 runs, all passing.

- [ ] **Step 5: Run standardrb**

```bash
bundle exec standardrb --fix
```

- [ ] **Step 6: Commit**

```bash
git add lib/esper_lint/parsing.rb test/test_parsing.rb
git commit -m "feat: Parsing — manifest cursor and index table parsers (TDD)"
```

---

## Task 5: Repo — eager loader

**Files:**
- Modify: `lib/esper_lint/repo.rb`
- Create: `test/test_repo.rb`

`Repo` walks the esper directory once, parses everything, and caches it. It's the single source of truth that all checks/queries/fixes consult.

**Public interface:**
- `EsperLint::Repo.new(esper_dir) → repo` — raises `Error(ESPER_DIR_MISSING | INDEX_MISSING)` on bad input; emits stderr warnings for malformed individual files but doesn't raise
- `repo.esper_dir → Pathname`
- `repo.topics → Array<TopicRecord>` — `{ slug, path, frontmatter, l0, sources_slugs (in document order), has_connections, raw_text }`
- `repo.sources → Array<SourceRecord>` — `{ slug, path, frontmatter, topics }`
- `repo.manifests → Array<ManifestRecord>` — `{ filename, path, cursor }`
- `repo.index_rows → Array<IndexRow>` — from `Parsing.parse_index_table`
- `repo.topic(slug) → TopicRecord | nil`
- `repo.source(slug) → SourceRecord | nil`
- `repo.topic_slugs → Set<String>`
- `repo.source_slugs → Set<String>`
- `repo.warnings → Array<Hash>` (warnings collected during load — for eventual stderr emission)
- `repo.references_to_source(slug) → Array<String>` — topic slugs that link to this source (computed lazily, cached)

Use `Struct` or `Data` for the records. Use `Set` from `set` stdlib.

- [ ] **Step 1: Write failing tests in `test/test_repo.rb`**

```ruby
# frozen_string_literal: true

require_relative "test_helper"

class TestRepo < Minitest::Test
  def repo
    @repo ||= EsperLint::Repo.new(FIXTURE_ROOT)
  end

  def test_loads_topics
    slugs = repo.topics.map(&:slug).sort
    expected = %w[topic-clean topic-duplicate-sources topic-empty topic-mismatch topic-no-connections topic-with-tag-shared]
    assert_equal expected, slugs
  end

  def test_loads_sources
    assert_equal 12, repo.sources.size
    assert_includes repo.source_slugs, "source-unicode-éàü"
    assert_includes repo.source_slugs, "source-stub-twin-9359a1"
  end

  def test_loads_manifests
    assert_equal 2, repo.manifests.size
  end

  def test_loads_index_rows
    assert_equal 6, repo.index_rows.size
  end

  def test_topic_lookup_by_slug
    t = repo.topic("topic-clean")
    refute_nil t
    assert_equal 2, t.frontmatter["source_count"]
    assert t.has_connections
  end

  def test_topic_no_connections_flag
    t = repo.topic("topic-no-connections")
    refute t.has_connections
  end

  def test_source_lookup_by_slug
    s = repo.source("source-stub")
    refute_nil s
    assert_equal [], s.topics
  end

  def test_references_to_source_returns_linking_topics
    refs = repo.references_to_source("source-tagged-topic-clean")
    assert_equal ["topic-clean"], refs
  end

  def test_references_to_source_returns_empty_for_orphan
    assert_equal [], repo.references_to_source("source-fixable-orphan")
  end

  def test_raises_when_esper_dir_missing
    err = assert_raises(EsperLint::Error) { EsperLint::Repo.new("/nonexistent/path") }
    assert_equal :ESPER_DIR_MISSING, err.code
  end

  def test_raises_when_index_missing
    Dir.mktmpdir do |tmp|
      Dir.mkdir(File.join(tmp, "pages"))
      Dir.mkdir(File.join(tmp, "pages/topics"))
      Dir.mkdir(File.join(tmp, "pages/sources"))
      err = assert_raises(EsperLint::Error) { EsperLint::Repo.new(tmp) }
      assert_equal :INDEX_MISSING, err.code
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec ruby -Ilib -Itest test/test_repo.rb
```

Expected: 11 failures.

- [ ] **Step 3: Implement `lib/esper_lint/repo.rb`**

```ruby
# frozen_string_literal: true

require "pathname"
require "set"
require "tmpdir"

module EsperLint
  TopicRecord = Struct.new(:slug, :path, :frontmatter, :l0, :sources_slugs, :has_connections, :raw_text, keyword_init: true)
  SourceRecord = Struct.new(:slug, :path, :frontmatter, :topics, keyword_init: true)
  ManifestRecord = Struct.new(:filename, :path, :cursor, keyword_init: true)

  class Repo
    attr_reader :esper_dir, :topics, :sources, :manifests, :index_rows, :warnings

    def initialize(esper_dir)
      @esper_dir = Pathname.new(esper_dir).expand_path
      raise Error.new(code: :ESPER_DIR_MISSING, message: "esper-dir not found: #{esper_dir}", path: esper_dir.to_s) unless @esper_dir.directory?

      index_path = @esper_dir.join("index.md")
      raise Error.new(code: :INDEX_MISSING, message: "index.md not found at #{index_path}", path: index_path.to_s) unless index_path.file?

      @warnings = []
      @topics = load_topics
      @sources = load_sources
      @manifests = load_manifests
      @index_rows = Parsing.parse_index_table(index_path.read)
      @topic_index = @topics.to_h { |t| [t.slug, t] }
      @source_index = @sources.to_h { |s| [s.slug, s] }
      @references_cache = nil
    end

    def topic(slug)
      @topic_index[slug]
    end

    def source(slug)
      @source_index[slug]
    end

    def topic_slugs
      @topic_slugs ||= @topics.map(&:slug).to_set
    end

    def source_slugs
      @source_slugs ||= @sources.map(&:slug).to_set
    end

    def references_to_source(slug)
      build_references_cache unless @references_cache
      @references_cache[slug] || []
    end

    private

    def load_topics
      glob = @esper_dir.join("pages/topics/*.md")
      Dir[glob.to_s].sort.map do |path|
        text = File.read(path)
        slug = File.basename(path, ".md")
        begin
          fm = Parsing.parse_frontmatter(text)
        rescue Error => e
          @warnings << {warning: "malformed_frontmatter", path: path, message: e.message}
          fm = {}
        end
        TopicRecord.new(
          slug: slug,
          path: Pathname.new(path),
          frontmatter: fm,
          l0: Parsing.extract_l0(text),
          sources_slugs: Parsing.extract_sources(text),
          has_connections: text.each_line.any? { |l| l.rstrip == "## Connections" },
          raw_text: text
        )
      end
    end

    def load_sources
      glob = @esper_dir.join("pages/sources/*.md")
      Dir[glob.to_s].sort.map do |path|
        text = File.read(path)
        slug = File.basename(path, ".md")
        begin
          fm = Parsing.parse_frontmatter(text)
        rescue Error => e
          @warnings << {warning: "malformed_frontmatter", path: path, message: e.message}
          fm = {}
        end
        SourceRecord.new(
          slug: slug,
          path: Pathname.new(path),
          frontmatter: fm,
          topics: Parsing.extract_topics_array(fm)
        )
      end
    end

    def load_manifests
      glob = @esper_dir.join("sources/*.{yml,yaml}")
      Dir[glob.to_s].sort.map do |path|
        text = File.read(path)
        cursor = begin
          Parsing.parse_manifest_cursor(text)
        rescue => e
          @warnings << {warning: "malformed_manifest", path: path, message: e.message}
          {kind: nil, value: nil}
        end
        ManifestRecord.new(filename: File.basename(path), path: Pathname.new(path), cursor: cursor)
      end
    end

    def build_references_cache
      @references_cache = Hash.new { |h, k| h[k] = [] }
      @topics.each do |t|
        t.sources_slugs.each { |s| @references_cache[s] << t.slug }
      end
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
bundle exec ruby -Ilib -Itest test/test_repo.rb
```

Expected: 11 runs, all pass.

- [ ] **Step 5: Run standardrb**

```bash
bundle exec standardrb --fix
```

- [ ] **Step 6: Commit**

```bash
git add lib/esper_lint/repo.rb test/test_repo.rb
git commit -m "feat: Repo — eager loader with caching (TDD)"
```

---

## Task 6: Checks — orphans

**Files:**
- Modify: `lib/esper_lint/checks.rb`
- Create: `test/test_checks.rb`

`Checks.orphans(repo) → Hash` matching the JSON shape:

```ruby
{
  total: Integer,
  by_class: { stub: N, fixable: N, subthreshold: N },
  items: [
    { slug:, class:, tags:, matching_topics: }
  ]
}
```

Items are sorted by slug ascending for deterministic output.

- [ ] **Step 1: Write failing test**

```ruby
# frozen_string_literal: true

require_relative "test_helper"

class TestChecks < Minitest::Test
  def repo
    @repo ||= EsperLint::Repo.new(FIXTURE_ROOT)
  end

  def test_orphans_returns_total_and_by_class
    result = EsperLint::Checks.orphans(repo)
    assert_equal 4, result[:total]
    assert_equal({stub: 2, fixable: 1, subthreshold: 1}, result[:by_class])
  end

  def test_orphans_classifies_stubs
    result = EsperLint::Checks.orphans(repo)
    stub = result[:items].find { |i| i[:slug] == "source-stub" }
    refute_nil stub
    assert_equal :stub, stub[:class]
    assert_equal [], stub[:tags]
    assert_equal [], stub[:matching_topics]
  end

  def test_orphans_classifies_fixable
    result = EsperLint::Checks.orphans(repo)
    fixable = result[:items].find { |i| i[:slug] == "source-fixable-orphan" }
    refute_nil fixable
    assert_equal :fixable, fixable[:class]
    assert_equal ["topic-with-tag-shared"], fixable[:tags]
    assert_equal ["topic-with-tag-shared"], fixable[:matching_topics]
  end

  def test_orphans_classifies_subthreshold
    result = EsperLint::Checks.orphans(repo)
    sub = result[:items].find { |i| i[:slug] == "source-subthreshold-orphan" }
    refute_nil sub
    assert_equal :subthreshold, sub[:class]
    assert_equal ["unique-tag-only"], sub[:tags]
    assert_equal [], sub[:matching_topics]
  end

  def test_orphans_items_sorted_by_slug
    result = EsperLint::Checks.orphans(repo)
    slugs = result[:items].map { |i| i[:slug] }
    assert_equal slugs.sort, slugs
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec ruby -Ilib -Itest test/test_checks.rb
```

Expected: 5 failures.

- [ ] **Step 3: Implement `Checks.orphans`**

In `lib/esper_lint/checks.rb`:

```ruby
# frozen_string_literal: true

module EsperLint
  module Checks
    module_function

    def orphans(repo)
      items = repo.sources
        .reject { |s| repo.references_to_source(s.slug).any? }
        .map { |s| classify_orphan(s, repo) }
        .sort_by { |i| i[:slug] }

      counts = items.group_by { |i| i[:class] }.transform_values(&:size)
      {
        total: items.size,
        by_class: {
          stub: counts[:stub] || 0,
          fixable: counts[:fixable] || 0,
          subthreshold: counts[:subthreshold] || 0
        },
        items: items
      }
    end

    def classify_orphan(source, repo)
      tags = source.topics
      matching = tags.select { |t| repo.topic_slugs.include?(t) }
      klass = if tags.empty?
        :stub
      elsif matching.any?
        :fixable
      else
        :subthreshold
      end
      {slug: source.slug, class: klass, tags: tags, matching_topics: matching}
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
bundle exec ruby -Ilib -Itest test/test_checks.rb
```

Expected: 5 runs, all pass.

- [ ] **Step 5: Run standardrb and commit**

```bash
bundle exec standardrb --fix
git add lib/esper_lint/checks.rb test/test_checks.rb
git commit -m "feat: Checks.orphans (TDD)"
```

---

## Task 7: Checks — source_count_mismatches, missing_connections, duplicate_sources

**Files:**
- Modify: `lib/esper_lint/checks.rb`
- Modify: `test/test_checks.rb`

Three small per-topic checks.

- [ ] **Step 1: Write failing tests**

Append to `test/test_checks.rb`:

```ruby
  def test_source_count_mismatches
    result = EsperLint::Checks.source_count_mismatches(repo)
    assert_equal 2, result[:total]
    items = result[:items]
    mismatch = items.find { |i| i[:topic] == "topic-mismatch" }
    refute_nil mismatch
    assert_equal 5, mismatch[:frontmatter]
    assert_equal 1, mismatch[:actual]
  end

  def test_missing_connections
    result = EsperLint::Checks.missing_connections(repo)
    assert_equal 1, result[:total]
    assert_equal ["topic-no-connections"], result[:items]
  end

  def test_duplicate_sources
    result = EsperLint::Checks.duplicate_sources(repo)
    assert_equal 1, result[:total]
    item = result[:items].first
    assert_equal "topic-duplicate-sources", item[:topic]
    assert_equal ["source-stub"], item[:duplicates]
  end
```

(Note: `topic-duplicate-sources` has source_count: 2 but only 1 unique link, so it appears in BOTH `source_count_mismatches` AND `duplicate_sources`. That's why total mismatches = 2.)

- [ ] **Step 2: Run tests to verify they fail**

Expected: 3 failures.

- [ ] **Step 3: Implement the three checks**

Append to `Checks` module:

```ruby
def source_count_mismatches(repo)
  items = repo.topics.filter_map do |t|
    fm_count = t.frontmatter["source_count"] || 0
    actual = t.sources_slugs.uniq.size  # NOTE: uniq for the count we'll bump to
    next if fm_count == actual

    {topic: t.slug, frontmatter: fm_count, actual: actual}
  end
  {total: items.size, items: items.sort_by { |i| i[:topic] }}
end

def missing_connections(repo)
  items = repo.topics.reject(&:has_connections).map(&:slug).sort
  {total: items.size, items: items}
end

def duplicate_sources(repo)
  items = repo.topics.filter_map do |t|
    counts = t.sources_slugs.tally
    dupes = counts.select { |_, n| n > 1 }.keys.sort
    next if dupes.empty?

    {topic: t.slug, duplicates: dupes}
  end
  {total: items.size, items: items.sort_by { |i| i[:topic] }}
end

module_function :source_count_mismatches, :missing_connections, :duplicate_sources
```

**Important:** The "actual" count for `source_count_mismatches` uses `.uniq.size` — this matches what `bump_source_counts` will write after `dedup_sources` runs. Without `.uniq`, `topic-duplicate-sources` would report `frontmatter: 2, actual: 2` (correct pre-dedup) but then bump to `2` again post-dedup, leaving the field stale. Computing against the deduplicated count makes the check forward-compatible with the fix.

- [ ] **Step 4: Run tests**

Expected: all pass.

- [ ] **Step 5: standardrb + commit**

```bash
bundle exec standardrb --fix
git add lib/esper_lint/checks.rb test/test_checks.rb
git commit -m "feat: Checks — source_count_mismatches, missing_connections, duplicate_sources (TDD)"
```

---

## Task 8: Checks — missing_topic_candidates, stale_manifests, index_drift

**Files:**
- Modify: `lib/esper_lint/checks.rb`
- Modify: `test/test_checks.rb`

- [ ] **Step 1: Write failing tests**

```ruby
  def test_missing_topic_candidates_with_default_threshold
    result = EsperLint::Checks.missing_topic_candidates(repo, threshold: 3)
    assert_equal 3, result[:threshold]
    assert_equal 1, result[:total]
    item = result[:items].first
    assert_equal "shared-missing-tag", item[:tag]
    assert_equal 3, item[:count]
  end

  def test_missing_topic_candidates_threshold_2
    result = EsperLint::Checks.missing_topic_candidates(repo, threshold: 2)
    tags = result[:items].map { |i| i[:tag] }
    assert_includes tags, "shared-missing-tag"
    refute_includes tags, "topic-clean"  # has a topic page; excluded
  end

  def test_stale_manifests_default
    result = EsperLint::Checks.stale_manifests(repo, stale_days: 30, today: Date.new(2026, 5, 5))
    assert_equal 30, result[:stale_days_threshold]
    items = result[:items]
    stale = items.find { |i| i[:file] == "manifest-stale.yml" }
    refute_nil stale
    assert_nil stale[:age_days]
    refute items.any? { |i| i[:file] == "manifest-fresh.yml" }
  end

  def test_stale_manifests_includes_aged_dates
    result = EsperLint::Checks.stale_manifests(repo, stale_days: 1, today: Date.new(2026, 5, 5))
    fresh = result[:items].find { |i| i[:file] == "manifest-fresh.yml" }
    refute_nil fresh  # 4 days old, > 1 day threshold
    assert_equal 4, fresh[:age_days]
  end

  def test_index_drift_count_mismatch
    result = EsperLint::Checks.index_drift(repo)
    assert_equal 1, result[:total]
    item = result[:items].first
    assert_equal :count_mismatch, item[:kind]
    assert_equal "topic-mismatch", item[:topic]
    assert_equal 1, item[:details][:disk_count]
    assert_equal 5, item[:details][:index_count]
  end
```

(Re `index_drift`: in our fixture, `topic-mismatch` has frontmatter source_count=5 but only 1 actual link. The index also says 5. The "disk count" the check should compare against is the post-dedup actual count — i.e. `t.sources_slugs.uniq.size` — to avoid double-reporting. Drift = 5 (index) vs 1 (actual). All other rows are consistent.)

- [ ] **Step 2: Run tests to verify they fail**

Expected: 5 failures.

- [ ] **Step 3: Implement the three checks**

```ruby
def missing_topic_candidates(repo, threshold:)
  freq = Hash.new(0)
  repo.sources.each { |s| s.topics.each { |t| freq[t] += 1 } }
  items = freq
    .select { |tag, count| count >= threshold && !repo.topic_slugs.include?(tag) }
    .map { |tag, count| {tag: tag, count: count} }
    .sort_by { |i| [-i[:count], i[:tag]] }
  {total: items.size, threshold: threshold, items: items}
end

def stale_manifests(repo, stale_days:, today: Date.today)
  items = repo.manifests.filter_map do |m|
    cursor = m.cursor
    value = cursor[:value]
    age_days = nil
    is_stale = false
    if value.nil?
      is_stale = cursor[:kind].nil? || true  # null cursor or no cursor block
    else
      date = value.is_a?(Date) ? value : Date.parse(value.to_s)
      age_days = (today - date).to_i
      is_stale = age_days >= stale_days
    end
    next unless is_stale

    {
      file: m.filename,
      cursor_kind: cursor[:kind]&.to_s,
      value: value.is_a?(Date) ? value.to_s : value,
      age_days: age_days,
      is_stale: true
    }
  end
  {total: items.size, stale_days_threshold: stale_days, items: items.sort_by { |i| i[:file] }}
end

def index_drift(repo)
  disk_slugs = repo.topic_slugs
  index_slugs = repo.index_rows.map { |r| r[:slug] }.to_set
  items = []

  (disk_slugs - index_slugs).sort.each do |slug|
    items << {kind: :missing_from_index, topic: slug, details: {}}
  end

  (index_slugs - disk_slugs).sort.each do |slug|
    items << {kind: :extra_in_index, topic: slug, details: {}}
  end

  repo.index_rows.each do |row|
    t = repo.topic(row[:slug])
    next unless t

    actual = t.sources_slugs.uniq.size
    next if actual == row[:count]

    items << {
      kind: :count_mismatch,
      topic: row[:slug],
      details: {disk_count: actual, index_count: row[:count]}
    }
  end

  {total: items.size, items: items}
end

module_function :missing_topic_candidates, :stale_manifests, :index_drift
```

- [ ] **Step 4: Run tests**

Expected: all pass.

- [ ] **Step 5: standardrb + commit**

```bash
bundle exec standardrb --fix
git add lib/esper_lint/checks.rb test/test_checks.rb
git commit -m "feat: Checks — missing_topic_candidates, stale_manifests, index_drift (TDD)"
```

---

## Task 9: Queries — sources, topics, tags, manifests

**Files:**
- Modify: `lib/esper_lint/queries.rb`
- Create: `test/test_queries.rb`

Each query method takes the repo and a kwargs hash of filters; returns `{ total:, results: [...] }`. Filter combinations use AND semantics.

**Methods:**
- `Queries.sources(repo, orphan: false, fixable: false, tag: nil, topic: nil)`
- `Queries.topics(repo, count_mismatch: false, missing_connections: false)`
- `Queries.tags(repo, threshold: 1, missing_page: false)`
- `Queries.manifests(repo, stale: false, stale_days: 30, today: Date.today)`

- [ ] **Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require_relative "test_helper"

class TestQueries < Minitest::Test
  def repo
    @repo ||= EsperLint::Repo.new(FIXTURE_ROOT)
  end

  def test_sources_no_filters_returns_all
    result = EsperLint::Queries.sources(repo)
    assert_equal 12, result[:total]
  end

  def test_sources_orphan_filter
    result = EsperLint::Queries.sources(repo, orphan: true)
    slugs = result[:results].map { |r| r[:slug] }
    assert_equal 4, result[:total]
    assert_includes slugs, "source-stub"
    assert_includes slugs, "source-fixable-orphan"
  end

  def test_sources_orphan_and_fixable
    result = EsperLint::Queries.sources(repo, orphan: true, fixable: true)
    slugs = result[:results].map { |r| r[:slug] }
    assert_equal ["source-fixable-orphan"], slugs
  end

  def test_sources_by_tag
    result = EsperLint::Queries.sources(repo, tag: "shared-missing-tag")
    assert_equal 3, result[:total]
  end

  def test_sources_by_topic
    result = EsperLint::Queries.sources(repo, topic: "topic-clean")
    slugs = result[:results].map { |r| r[:slug] }.sort
    assert_equal ["source-tagged-topic-clean", "source-unicode-éàü"], slugs
  end

  def test_topics_count_mismatch
    result = EsperLint::Queries.topics(repo, count_mismatch: true)
    slugs = result[:results].map { |r| r[:slug] }.sort
    assert_includes slugs, "topic-mismatch"
  end

  def test_topics_missing_connections
    result = EsperLint::Queries.topics(repo, missing_connections: true)
    slugs = result[:results].map { |r| r[:slug] }
    assert_equal ["topic-no-connections"], slugs
  end

  def test_tags_with_threshold
    result = EsperLint::Queries.tags(repo, threshold: 3)
    tags = result[:results].map { |r| r[:tag] }
    assert_includes tags, "shared-missing-tag"
  end

  def test_tags_missing_page
    result = EsperLint::Queries.tags(repo, threshold: 3, missing_page: true)
    assert(result[:results].all? { |r| r[:has_topic_page] == false })
  end

  def test_manifests_stale_filter
    result = EsperLint::Queries.manifests(repo, stale: true, stale_days: 30, today: Date.new(2026, 5, 5))
    files = result[:results].map { |r| r[:file] }
    assert_equal ["manifest-stale.yml"], files
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: 10 failures.

- [ ] **Step 3: Implement `lib/esper_lint/queries.rb`**

```ruby
# frozen_string_literal: true

module EsperLint
  module Queries
    module_function

    def sources(repo, orphan: false, fixable: false, tag: nil, topic: nil)
      results = repo.sources.map do |s|
        linked_from = repo.references_to_source(s.slug)
        is_orphan = linked_from.empty?
        is_stub = s.topics.empty?
        matching = s.topics.select { |t| repo.topic_slugs.include?(t) }
        {
          slug: s.slug,
          tags: s.topics,
          linked_from_topics: linked_from,
          is_orphan: is_orphan,
          is_stub: is_stub,
          matching_topics: matching
        }
      end

      results = results.select { |r| r[:is_orphan] } if orphan
      results = results.select { |r| !r[:is_stub] && r[:matching_topics].any? } if fixable
      results = results.select { |r| r[:tags].include?(tag) } if tag
      if topic
        sources_in_topic = repo.topic(topic)&.sources_slugs&.to_set || Set.new
        results = results.select { |r| sources_in_topic.include?(r[:slug]) }
      end

      results = results.sort_by { |r| r[:slug] }
      {total: results.size, results: results}
    end

    def topics(repo, count_mismatch: false, missing_connections: false)
      results = repo.topics.map do |t|
        actual = t.sources_slugs.uniq.size
        {
          slug: t.slug,
          source_count_frontmatter: t.frontmatter["source_count"] || 0,
          source_count_actual: actual,
          has_connections: t.has_connections,
          l0: t.l0
        }
      end

      results = results.select { |r| r[:source_count_frontmatter] != r[:source_count_actual] } if count_mismatch
      results = results.reject { |r| r[:has_connections] } if missing_connections

      results = results.sort_by { |r| r[:slug] }
      {total: results.size, results: results}
    end

    def tags(repo, threshold: 1, missing_page: false)
      freq = Hash.new(0)
      repo.sources.each { |s| s.topics.each { |t| freq[t] += 1 } }
      results = freq
        .select { |_, count| count >= threshold }
        .map { |tag, count| {tag: tag, count: count, has_topic_page: repo.topic_slugs.include?(tag)} }

      results = results.reject { |r| r[:has_topic_page] } if missing_page

      results = results.sort_by { |r| [-r[:count], r[:tag]] }
      {total: results.size, results: results}
    end

    def manifests(repo, stale: false, stale_days: 30, today: Date.today)
      results = repo.manifests.map do |m|
        cursor = m.cursor
        value = cursor[:value]
        age_days = nil
        is_stale = false
        if value.nil?
          is_stale = true
        else
          date = value.is_a?(Date) ? value : Date.parse(value.to_s)
          age_days = (today - date).to_i
          is_stale = age_days >= stale_days
        end
        {
          file: m.filename,
          cursor_kind: cursor[:kind]&.to_s,
          value: value.is_a?(Date) ? value.to_s : value,
          age_days: age_days,
          is_stale: is_stale
        }
      end

      results = results.select { |r| r[:is_stale] } if stale

      results = results.sort_by { |r| r[:file] }
      {total: results.size, results: results}
    end
  end
end
```

- [ ] **Step 4: Run tests**

Expected: all pass.

- [ ] **Step 5: standardrb + commit**

```bash
bundle exec standardrb --fix
git add lib/esper_lint/queries.rb test/test_queries.rb
git commit -m "feat: Queries — sources, topics, tags, manifests with filters (TDD)"
```

---

## Task 10: Fixes — bump_source_counts and dedup_sources

**Files:**
- Modify: `lib/esper_lint/fixes.rb`
- Create: `test/test_fixes.rb`

Both fixes mutate topic page files. The strategy:
1. Read the file
2. Identify the `## Sources` block (start line + end line, where end is either the next `## ` heading or end-of-file)
3. Rewrite the block (sorted, dedup'd)
4. Update `source_count` in the YAML frontmatter

A helper `Fixes.write_topic_page(topic, new_sources_slugs, new_source_count)` does the surgery. Tests use a tmp copy of the fixture so the original is preserved.

**Important:** All fix tests use `Dir.mktmpdir` and copy the fixture into the tmp directory. Tests must NEVER modify `test/fixtures/`.

- [ ] **Step 1: Write a test helper in `test/test_helper.rb`**

Append:

```ruby
require "fileutils"
require "tmpdir"

def with_tmp_esper
  Dir.mktmpdir do |tmp|
    target = File.join(tmp, "esper")
    FileUtils.cp_r(FIXTURE_ROOT, target)
    yield target
  end
end
```

- [ ] **Step 2: Write failing tests in `test/test_fixes.rb`**

```ruby
# frozen_string_literal: true

require_relative "test_helper"

class TestFixes < Minitest::Test
  include Module.new {
    def with_tmp_esper(&block)
      Dir.mktmpdir do |tmp|
        target = File.join(tmp, "esper")
        FileUtils.cp_r(FIXTURE_ROOT, target)
        block.call(target)
      end
    end
  }

  def test_bump_source_counts_returns_changes
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      result = EsperLint::Fixes.bump_source_counts(repo)
      bumps = result.sort_by { |b| b[:topic] }
      assert(bumps.any? { |b| b[:topic] == "topic-mismatch" && b[:from] == 5 && b[:to] == 1 })
    end
  end

  def test_bump_source_counts_persists_to_file
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      EsperLint::Fixes.bump_source_counts(repo)
      text = File.read(File.join(dir, "pages/topics/topic-mismatch.md"))
      assert_match(/^source_count:\s*1\s*$/, text)
    end
  end

  def test_dedup_sources_removes_duplicates
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      result = EsperLint::Fixes.dedup_sources(repo)
      assert(result.any? { |d| d[:topic] == "topic-duplicate-sources" })
      text = File.read(File.join(dir, "pages/topics/topic-duplicate-sources.md"))
      assert_equal 1, text.scan(/^- \[\[pages\/sources\/source-stub\]\]/).size
    end
  end

  def test_dedup_then_bump_yields_correct_count
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      EsperLint::Fixes.dedup_sources(repo)
      repo2 = EsperLint::Repo.new(dir)  # reload after mutation
      EsperLint::Fixes.bump_source_counts(repo2)
      text = File.read(File.join(dir, "pages/topics/topic-duplicate-sources.md"))
      assert_match(/^source_count:\s*1\s*$/, text)
    end
  end

  def test_idempotent
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      EsperLint::Fixes.dedup_sources(repo)
      EsperLint::Fixes.bump_source_counts(EsperLint::Repo.new(dir))
      result = EsperLint::Fixes.bump_source_counts(EsperLint::Repo.new(dir))
      assert_empty result
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Expected: 5 failures.

- [ ] **Step 4: Implement `lib/esper_lint/fixes.rb`**

```ruby
# frozen_string_literal: true

module EsperLint
  module Fixes
    SOURCE_COUNT_RE = /^source_count:\s*\d+\s*$/

    module_function

    def bump_source_counts(repo)
      changes = []
      repo.topics.each do |t|
        actual = t.sources_slugs.uniq.size
        fm_count = t.frontmatter["source_count"] || 0
        next if fm_count == actual

        new_text = update_source_count(t.raw_text, actual)
        File.write(t.path, new_text)
        changes << {topic: t.slug, from: fm_count, to: actual}
      end
      changes
    end

    def dedup_sources(repo)
      changes = []
      repo.topics.each do |t|
        original = t.sources_slugs
        deduped = original.uniq
        next if original == deduped

        removed = original.tally.select { |_, n| n > 1 }.keys.sort
        new_text = rewrite_sources_section(t.raw_text, deduped.sort_by(&:downcase))
        File.write(t.path, new_text)
        changes << {topic: t.slug, removed: removed}
      end
      changes
    end

    # ---- helpers ----

    def update_source_count(text, new_count)
      if text.match?(SOURCE_COUNT_RE)
        text.sub(SOURCE_COUNT_RE, "source_count: #{new_count}")
      else
        # Field missing from frontmatter — add it
        warn "warning: adding missing source_count field"
        text.sub(/^---\s*\n/, "---\nsource_count: #{new_count}\n")
      end
    end

    def rewrite_sources_section(text, new_slugs)
      lines = text.lines
      start_idx = lines.find_index { |l| l.rstrip == "## Sources" }
      return text unless start_idx

      end_idx = lines[(start_idx + 1)..].find_index { |l| l.start_with?("## ") }
      end_idx = end_idx ? start_idx + 1 + end_idx : lines.size

      # Preserve any trailing non-link content (blank lines) before the next section
      trailing_blanks = []
      i = end_idx - 1
      while i > start_idx && lines[i].strip.empty?
        trailing_blanks.unshift(lines[i])
        i -= 1
      end

      new_block = ["## Sources\n"]
      new_block += new_slugs.map { |s| "- [[pages/sources/#{s}]]\n" }
      new_block += trailing_blanks

      (lines[0...start_idx] + new_block + lines[end_idx..]).join
    end
  end
end
```

- [ ] **Step 5: Run tests**

Expected: all pass.

- [ ] **Step 6: standardrb + commit**

```bash
bundle exec standardrb --fix
git add lib/esper_lint/fixes.rb test/test_fixes.rb test/test_helper.rb
git commit -m "feat: Fixes — bump_source_counts and dedup_sources (TDD)"
```

---

## Task 11: Fixes — rebuild_index

**Files:**
- Modify: `lib/esper_lint/fixes.rb`
- Modify: `test/test_fixes.rb`

`Fixes.rebuild_index(repo, today: Date.today)` writes a fresh `index.md` from current topic state.

Output format (must match the existing index style):
```markdown
<!-- L0: Two-tier topic index — entry point for all Esper queries -->
# Esper Index

## Topics

| Topic | Sources | Last Updated | Summary |
|-------|---------|--------------|---------|
| [[pages/topics/SLUG]] | N | YYYY-MM-DD | summary text |
| ...
```

Sort order: `source_count` desc, then slug asc.

Date semantics:
- If a topic's slug is new (not in old index) → use `today`
- If a topic's `source_count` differs from old index `count` → use `today`
- Otherwise preserve the old date

- [ ] **Step 1: Write failing tests**

Append to `test/test_fixes.rb`:

```ruby
  def test_rebuild_index_updates_dates_for_changed_counts
    with_tmp_esper do |dir|
      # First, fix counts so the topic-mismatch frontmatter goes from 5 to 1
      repo = EsperLint::Repo.new(dir)
      EsperLint::Fixes.bump_source_counts(repo)
      EsperLint::Fixes.dedup_sources(EsperLint::Repo.new(dir))
      repo2 = EsperLint::Repo.new(dir)
      result = EsperLint::Fixes.rebuild_index(repo2, today: Date.new(2026, 5, 5))
      text = File.read(File.join(dir, "index.md"))
      # topic-mismatch should now show count 1 with today's date
      assert_match(/\[\[pages\/topics\/topic-mismatch\]\]\s*\|\s*1\s*\|\s*2026-05-05/, text)
    end
  end

  def test_rebuild_index_preserves_dates_for_unchanged_topics
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      EsperLint::Fixes.rebuild_index(repo, today: Date.new(2026, 5, 5))
      text = File.read(File.join(dir, "index.md"))
      # topic-clean is unchanged; date stays 2026-04-01
      assert_match(/\[\[pages\/topics\/topic-clean\]\]\s*\|\s*2\s*\|\s*2026-04-01/, text)
    end
  end

  def test_rebuild_index_sorts_by_count_desc
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      EsperLint::Fixes.rebuild_index(repo, today: Date.new(2026, 5, 5))
      text = File.read(File.join(dir, "index.md"))
      # Find the lines for two known counts and assert order
      mismatch_idx = text.index("topic-mismatch")
      empty_idx = text.index("topic-empty")
      refute_nil mismatch_idx
      refute_nil empty_idx
      assert mismatch_idx < empty_idx, "expected topic-mismatch (count 5) to appear before topic-empty (count 0)"
    end
  end

  def test_rebuild_index_uses_l0_for_summary
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      EsperLint::Fixes.rebuild_index(repo, today: Date.new(2026, 5, 5))
      text = File.read(File.join(dir, "index.md"))
      assert_includes text, "Empty topic — zero sources, valid"
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: 4 failures.

- [ ] **Step 3: Implement `Fixes.rebuild_index`**

Append to `Fixes` module:

```ruby
INDEX_TEMPLATE_HEADER = <<~MD
  <!-- L0: Two-tier topic index — entry point for all Esper queries -->
  # Esper Index

  ## Topics

  | Topic | Sources | Last Updated | Summary |
  |-------|---------|--------------|---------|
MD

def rebuild_index(repo, today: Date.today)
  old_rows = repo.index_rows.to_h { |r| [r[:slug], r] }
  rows_added = []
  rows_removed = old_rows.keys - repo.topic_slugs.to_a
  count_changes = []

  sorted_topics = repo.topics.sort_by { |t| [-t.frontmatter.fetch("source_count", 0), t.slug] }

  body_lines = sorted_topics.map do |t|
    slug = t.slug
    count = t.frontmatter.fetch("source_count", 0)
    summary = t.l0 || ""
    old = old_rows[slug]
    date = if old.nil?
      rows_added << slug
      today.to_s
    elsif old[:count] != count
      count_changes << {topic: slug, from: old[:count], to: count}
      today.to_s
    else
      old[:date]
    end
    "| [[pages/topics/#{slug}]] | #{count} | #{date} | #{summary} |"
  end

  warn_missing_l0 = sorted_topics.select { |t| t.l0.nil? }
  warn_missing_l0.each do |t|
    warn "warning: topic #{t.slug} has no L0 header; index summary will be empty"
  end

  index_path = repo.esper_dir.join("index.md")
  File.write(index_path, INDEX_TEMPLATE_HEADER + body_lines.join("\n") + "\n")

  {
    rows_before: old_rows.size,
    rows_after: sorted_topics.size,
    topics_added: rows_added,
    topics_removed: rows_removed,
    count_changes: count_changes
  }
end

module_function :rebuild_index
```

- [ ] **Step 4: Run tests**

Expected: all pass.

- [ ] **Step 5: standardrb + commit**

```bash
bundle exec standardrb --fix
git add lib/esper_lint/fixes.rb test/test_fixes.rb
git commit -m "feat: Fixes.rebuild_index (TDD)"
```

---

## Task 12: Mutations — add_source

**Files:**
- Modify: `lib/esper_lint/mutations.rb`
- Create: `test/test_mutations.rb`

`Mutations.add_source(repo, topic_slug, source_slug) → Hash`. Behavior:
- Raises `Error(:UNKNOWN_TOPIC)` if topic doesn't exist
- Raises `Error(:UNKNOWN_SOURCE)` if source slug doesn't exist on disk
- If source already in topic's Sources list: returns `was_already_present: true`, no file change
- Otherwise: rewrites Sources (sorted, dedup'd, with new slug); bumps source_count

Reuses `Fixes.rewrite_sources_section` and `Fixes.update_source_count`.

- [ ] **Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require_relative "test_helper"

class TestMutations < Minitest::Test
  def with_tmp_esper(&block)
    Dir.mktmpdir do |tmp|
      target = File.join(tmp, "esper")
      FileUtils.cp_r(FIXTURE_ROOT, target)
      block.call(target)
    end
  end

  def test_add_source_to_topic
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      result = EsperLint::Mutations.add_source(repo, "topic-clean", "source-fixable-orphan")
      assert_equal false, result[:was_already_present]
      assert_equal 2, result[:source_count][:from]
      assert_equal 3, result[:source_count][:to]

      text = File.read(File.join(dir, "pages/topics/topic-clean.md"))
      assert_match(/source-fixable-orphan/, text)
      assert_match(/^source_count:\s*3\s*$/, text)
    end
  end

  def test_add_source_idempotent_when_already_present
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      result = EsperLint::Mutations.add_source(repo, "topic-clean", "source-tagged-topic-clean")
      assert_equal true, result[:was_already_present]
      assert_equal result[:source_count][:from], result[:source_count][:to]
    end
  end

  def test_add_source_unknown_topic_raises
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      err = assert_raises(EsperLint::Error) do
        EsperLint::Mutations.add_source(repo, "nonexistent-topic", "source-stub")
      end
      assert_equal :UNKNOWN_TOPIC, err.code
    end
  end

  def test_add_source_unknown_source_raises
    with_tmp_esper do |dir|
      repo = EsperLint::Repo.new(dir)
      err = assert_raises(EsperLint::Error) do
        EsperLint::Mutations.add_source(repo, "topic-clean", "nonexistent-source")
      end
      assert_equal :UNKNOWN_SOURCE, err.code
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: 4 failures.

- [ ] **Step 3: Implement `lib/esper_lint/mutations.rb`**

```ruby
# frozen_string_literal: true

module EsperLint
  module Mutations
    module_function

    def add_source(repo, topic_slug, source_slug)
      topic = repo.topic(topic_slug)
      raise Error.new(code: :UNKNOWN_TOPIC, message: "no topic page for slug: #{topic_slug}") unless topic
      raise Error.new(code: :UNKNOWN_SOURCE, message: "no source page for slug: #{source_slug}") unless repo.source(source_slug)

      existing = topic.sources_slugs
      if existing.include?(source_slug)
        return {
          topic: topic_slug,
          source_added: source_slug,
          source_count: {from: topic.frontmatter["source_count"] || 0, to: topic.frontmatter["source_count"] || 0},
          was_already_present: true
        }
      end

      new_slugs = (existing + [source_slug]).uniq.sort_by(&:downcase)
      new_text = Fixes.rewrite_sources_section(topic.raw_text, new_slugs)
      new_count = new_slugs.size
      old_count = topic.frontmatter["source_count"] || 0
      new_text = Fixes.update_source_count(new_text, new_count)
      File.write(topic.path, new_text)

      {
        topic: topic_slug,
        source_added: source_slug,
        source_count: {from: old_count, to: new_count},
        was_already_present: false
      }
    end
  end
end
```

- [ ] **Step 4: Run tests**

Expected: all pass.

- [ ] **Step 5: standardrb + commit**

```bash
bundle exec standardrb --fix
git add lib/esper_lint/mutations.rb test/test_mutations.rb
git commit -m "feat: Mutations.add_source with idempotency and validation (TDD)"
```

---

## Task 13: Git — clean-tree check

**Files:**
- Modify: `lib/esper_lint/git.rb`
- Create: `test/test_git.rb`

`Git.working_tree_clean?(esper_dir) → Boolean`. Shells out: `git status --porcelain -- <esper_dir>`. Returns true iff stdout is empty.

- [ ] **Step 1: Write tests**

```ruby
# frozen_string_literal: true

require_relative "test_helper"

class TestGit < Minitest::Test
  def test_returns_true_for_clean_repo
    Dir.mktmpdir do |tmp|
      Dir.chdir(tmp) do
        system("git init -q")
        system("git -c user.email=a@b -c user.name=A commit --allow-empty -q -m init")
        Dir.mkdir("esper")
        # esper dir exists but git knows nothing about it; status will show it as untracked
        # However, since we ask git status -- esper, untracked under esper means not clean.
        # Add and commit a placeholder so the dir is "clean"
        File.write("esper/.gitkeep", "")
        system("git add esper/.gitkeep")
        system("git -c user.email=a@b -c user.name=A commit -q -m add")
        assert EsperLint::Git.working_tree_clean?(File.join(tmp, "esper"))
      end
    end
  end

  def test_returns_false_for_dirty_repo
    Dir.mktmpdir do |tmp|
      Dir.chdir(tmp) do
        system("git init -q")
        Dir.mkdir("esper")
        File.write("esper/dirty.txt", "uncommitted")
        refute EsperLint::Git.working_tree_clean?(File.join(tmp, "esper"))
      end
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: 2 failures.

- [ ] **Step 3: Implement**

```ruby
# frozen_string_literal: true

require "open3"

module EsperLint
  module Git
    module_function

    def working_tree_clean?(esper_dir)
      stdout, _stderr, _status = Open3.capture3("git", "status", "--porcelain", "--", esper_dir.to_s)
      stdout.strip.empty?
    end

    def porcelain_status(esper_dir)
      stdout, _stderr, _status = Open3.capture3("git", "status", "--porcelain", "--", esper_dir.to_s)
      stdout
    end
  end
end
```

- [ ] **Step 4: Run tests**

Expected: pass.

- [ ] **Step 5: standardrb + commit**

```bash
bundle exec standardrb --fix
git add lib/esper_lint/git.rb test/test_git.rb
git commit -m "feat: Git.working_tree_clean? via Open3 (TDD)"
```

---

## Task 14: CLI — option parsing and dispatch

**Files:**
- Modify: `lib/esper_lint/cli.rb`
- Create: `test/test_cli.rb`

`CLI.run(argv) → Integer (exit code)`. Parses subcommand + flags, calls into Checks/Queries/Fixes/Mutations, serializes JSON to stdout, emits warnings/errors to stderr.

JSON envelope (per spec):
```json
{
  "meta": { "esper_dir": "...", "ran_at": "...", "tool_version": "0.1.0", "subcommand": "check" },
  "...payload..."
}
```

- [ ] **Step 1: Write failing tests**

```ruby
# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "stringio"

class TestCLI < Minitest::Test
  def capture_io
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    code = yield
    [code, $stdout.string, $stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end

  def test_check_subcommand_returns_json_with_findings
    code, out, _err = capture_io { EsperLint::CLI.run(["check", "--esper-dir", FIXTURE_ROOT]) }
    json = JSON.parse(out)
    assert_equal "check", json["meta"]["subcommand"]
    assert_equal "0.1.0", json["meta"]["tool_version"]
    assert json["checks"]["orphans"]["total"] > 0
    assert_equal 1, code  # findings present
  end

  def test_no_subcommand_defaults_to_check
    code, out, _err = capture_io { EsperLint::CLI.run(["--esper-dir", FIXTURE_ROOT]) }
    json = JSON.parse(out)
    assert_equal "check", json["meta"]["subcommand"]
    assert_equal 1, code
  end

  def test_sources_orphan_flag
    code, out, _err = capture_io { EsperLint::CLI.run(["sources", "--orphan", "--esper-dir", FIXTURE_ROOT]) }
    json = JSON.parse(out)
    assert_equal 4, json["total"]
    assert_equal 0, code
  end

  def test_tags_threshold_flag
    code, out, _err = capture_io do
      EsperLint::CLI.run(["tags", "--threshold", "3", "--missing-page", "--esper-dir", FIXTURE_ROOT])
    end
    json = JSON.parse(out)
    assert(json["results"].any? { |r| r["tag"] == "shared-missing-tag" })
    assert_equal 0, code
  end

  def test_version_subcommand
    code, out, _err = capture_io { EsperLint::CLI.run(["version"]) }
    assert_includes out, "0.1.0"
    assert_equal 0, code
  end

  def test_missing_esper_dir_returns_2_with_error_envelope
    code, _out, err = capture_io { EsperLint::CLI.run(["check", "--esper-dir", "/nonexistent/path"]) }
    assert_equal 2, code
    err_json = JSON.parse(err)
    assert_equal "ESPER_DIR_MISSING", err_json["error"]["code"]
  end

  def test_invalid_subcommand_returns_2
    code, _out, err = capture_io { EsperLint::CLI.run(["bogus-subcommand"]) }
    assert_equal 2, code
    err_json = JSON.parse(err)
    assert_equal "INVALID_ARGUMENT", err_json["error"]["code"]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: 7 failures.

- [ ] **Step 3: Implement `lib/esper_lint/cli.rb`**

```ruby
# frozen_string_literal: true

require "optparse"
require "json"
require "date"

module EsperLint
  module CLI
    SUBCOMMANDS = %w[check fix sources topics tags manifests add-source help version].freeze

    module_function

    def run(argv)
      argv = argv.dup
      subcommand = argv.first && !argv.first.start_with?("-") ? argv.shift : "check"
      subcommand = "check" if subcommand.nil? || subcommand.empty?

      case subcommand
      when "version"
        puts "esper-lint #{EsperLint::VERSION}"
        return 0
      when "help"
        print_help(argv.first)
        return 0
      end

      unless SUBCOMMANDS.include?(subcommand)
        emit_error(:INVALID_ARGUMENT, "unknown subcommand: #{subcommand}")
        return 2
      end

      options = {
        esper_dir: "./esper",
        tag_threshold: 3,
        stale_days: 30
      }
      parse_options(subcommand, argv, options)

      repo = Repo.new(options[:esper_dir])
      emit_warnings(repo)

      meta = build_meta(options[:esper_dir], subcommand)
      payload, exit_code = dispatch(subcommand, repo, options, argv)

      puts JSON.generate(meta.merge(payload))
      exit_code
    rescue Error => e
      emit_error(e.code, e.message, path: e.path, details: e.details)
      2
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      emit_error(:INVALID_ARGUMENT, e.message)
      2
    end

    # ---- private ----

    def self.parse_options(subcommand, argv, options)
      parser = OptionParser.new do |o|
        o.on("--esper-dir PATH") { |v| options[:esper_dir] = v }
        o.on("--tag-threshold N", Integer) { |v| options[:tag_threshold] = v }
        o.on("--stale-days N", Integer) { |v| options[:stale_days] = v }

        case subcommand
        when "sources"
          o.on("--orphan") { options[:orphan] = true }
          o.on("--fixable") { options[:fixable] = true }
          o.on("--tag TAG") { |v| options[:tag] = v }
          o.on("--topic SLUG") { |v| options[:topic] = v }
        when "topics"
          o.on("--count-mismatch") { options[:count_mismatch] = true }
          o.on("--missing-connections") { options[:missing_connections] = true }
        when "tags"
          o.on("--threshold N", Integer) { |v| options[:threshold] = v }
          o.on("--missing-page") { options[:missing_page] = true }
        when "manifests"
          o.on("--stale") { options[:stale] = true }
        end
      end
      parser.parse!(argv)
    end

    def self.build_meta(esper_dir, subcommand)
      {
        "meta" => {
          "esper_dir" => File.expand_path(esper_dir),
          "ran_at" => Time.now.iso8601,
          "tool_version" => EsperLint::VERSION,
          "subcommand" => subcommand
        }
      }
    end

    def self.dispatch(subcommand, repo, options, argv)
      case subcommand
      when "check"
        run_check(repo, options)
      when "fix"
        run_fix(repo, options)
      when "sources"
        run_sources(repo, options)
      when "topics"
        run_topics(repo, options)
      when "tags"
        run_tags(repo, options)
      when "manifests"
        run_manifests(repo, options)
      when "add-source"
        run_add_source(repo, options, argv)
      end
    end

    def self.run_check(repo, options)
      payload = {
        "summary" => summary(repo),
        "checks" => {
          "orphans" => Checks.orphans(repo),
          "source_count_mismatches" => Checks.source_count_mismatches(repo),
          "missing_topic_candidates" => Checks.missing_topic_candidates(repo, threshold: options[:tag_threshold]),
          "missing_connections" => Checks.missing_connections(repo),
          "stale_manifests" => Checks.stale_manifests(repo, stale_days: options[:stale_days]),
          "index_drift" => Checks.index_drift(repo),
          "duplicate_sources" => Checks.duplicate_sources(repo)
        }
      }
      total_findings = payload["checks"].values.sum { |v| v[:total] || 0 }
      payload["summary"]["checks_with_findings"] = payload["checks"].values.count { |v| (v[:total] || 0) > 0 }
      [normalize_keys(payload), total_findings.zero? ? 0 : 1]
    end

    def self.run_fix(repo, options)
      unless Git.working_tree_clean?(repo.esper_dir.to_s)
        raise Error.new(
          code: :DIRTY_TREE,
          message: "git working tree under #{repo.esper_dir} has uncommitted changes; refusing to apply fix",
          path: repo.esper_dir.to_s,
          details: {porcelain_output: Git.porcelain_status(repo.esper_dir.to_s)}
        )
      end

      bumps = Fixes.bump_source_counts(repo)
      dedups = Fixes.dedup_sources(Repo.new(repo.esper_dir.to_s))
      bumps2 = Fixes.bump_source_counts(Repo.new(repo.esper_dir.to_s)) # post-dedup re-bump
      bumps += bumps2 unless bumps2.empty?
      index_result = Fixes.rebuild_index(Repo.new(repo.esper_dir.to_s))

      post_repo = Repo.new(repo.esper_dir.to_s)
      post_check, _ = run_check(post_repo, options)

      [
        normalize_keys({
          "applied" => {
            "source_count_bumps" => bumps,
            "dedup_sources" => dedups,
            "index_rebuilt" => index_result
          },
          "post_fix_check" => post_check.except("meta")
        }),
        0
      ]
    end

    def self.run_sources(repo, options)
      result = Queries.sources(repo,
        orphan: options[:orphan] || false,
        fixable: options[:fixable] || false,
        tag: options[:tag],
        topic: options[:topic])
      [normalize_keys({"filters" => filter_summary(options, [:orphan, :fixable, :tag, :topic])}.merge(result)), 0]
    end

    def self.run_topics(repo, options)
      result = Queries.topics(repo,
        count_mismatch: options[:count_mismatch] || false,
        missing_connections: options[:missing_connections] || false)
      [normalize_keys({"filters" => filter_summary(options, [:count_mismatch, :missing_connections])}.merge(result)), 0]
    end

    def self.run_tags(repo, options)
      threshold = options[:threshold] || 1
      result = Queries.tags(repo, threshold: threshold, missing_page: options[:missing_page] || false)
      [normalize_keys({"filters" => {"threshold" => threshold, "missing_page" => options[:missing_page] || false}}.merge(result)), 0]
    end

    def self.run_manifests(repo, options)
      result = Queries.manifests(repo, stale: options[:stale] || false, stale_days: options[:stale_days])
      [normalize_keys({"filters" => filter_summary(options, [:stale])}.merge(result)), 0]
    end

    def self.run_add_source(repo, options, argv)
      topic = argv[0] or raise Error.new(code: :INVALID_ARGUMENT, message: "add-source requires TOPIC_SLUG")
      source = argv[1] or raise Error.new(code: :INVALID_ARGUMENT, message: "add-source requires SOURCE_SLUG")
      result = Mutations.add_source(repo, topic, source)
      [normalize_keys({"applied" => result}), 0]
    end

    def self.summary(repo)
      {
        "topics" => repo.topics.size,
        "sources" => repo.sources.size,
        "manifests" => repo.manifests.size,
        "checks_with_findings" => 0
      }
    end

    def self.filter_summary(options, keys)
      keys.to_h { |k| [k.to_s, options[k] || false] }
    end

    def self.normalize_keys(obj)
      case obj
      when Hash
        obj.to_h { |k, v| [k.to_s, normalize_keys(v)] }
      when Array
        obj.map { |v| normalize_keys(v) }
      when Symbol
        obj.to_s
      else
        obj
      end
    end

    def self.emit_warnings(repo)
      repo.warnings.each { |w| warn JSON.generate(w) }
    end

    def self.emit_error(code, message, path: nil, details: {})
      warn JSON.generate(error: {code: code.to_s, message: message, path: path, details: details}.compact)
    end

    def self.print_help(_subcommand_name)
      puts <<~USAGE
        Usage: esper-lint [SUBCOMMAND] [options]

        Subcommands:
          check        Run all 7 lint checks (default)
          fix          Apply bump_source_counts, dedup_sources, rebuild_index
          sources      List source pages with optional filters
          topics       List topic pages with optional filters
          tags         List tags with optional filters
          manifests    List source manifests with optional filters
          add-source TOPIC_SLUG SOURCE_SLUG   Add source to topic's Sources list
          version      Print version
          help         Print this message

        Global options:
          --esper-dir PATH        Default: ./esper
          --tag-threshold N       Default: 3
          --stale-days N          Default: 30
      USAGE
    end
  end
end
```

(Note: `Hash#except` is used in `run_fix` — Ruby 3.0+. If targeting older Ruby, replace with `.reject { |k, _| k == "meta" }`.)

- [ ] **Step 4: Run tests**

```bash
bundle exec ruby -Ilib -Itest test/test_cli.rb
```

Expected: all 7 tests pass.

- [ ] **Step 5: Run the full test suite**

```bash
bundle exec rake test
```

Expected: all tests across all files pass.

- [ ] **Step 6: standardrb + commit**

```bash
bundle exec standardrb --fix
git add lib/esper_lint/cli.rb test/test_cli.rb
git commit -m "feat: CLI dispatch with OptionParser, JSON output, exit-code mapping (TDD)"
```

---

## Task 15: End-to-end CLI integration test (round-trip)

**Files:**
- Modify: `test/test_cli.rb`

A round-trip test that validates the spec invariant: after `fix` runs, re-running `check` should report zero findings for the fixable subset (source_count_mismatches, duplicate_sources, index_drift count_mismatches).

- [ ] **Step 1: Write failing test**

Append to `test/test_cli.rb`:

```ruby
  def test_fix_then_check_reports_no_fixable_findings
    Dir.mktmpdir do |tmp|
      target = File.join(tmp, "esper")
      FileUtils.cp_r(FIXTURE_ROOT, target)
      Dir.chdir(tmp) do
        system("git init -q")
        system("git -c user.email=a@b -c user.name=A add esper")
        system("git -c user.email=a@b -c user.name=A commit -q -m init")
      end

      capture_io { EsperLint::CLI.run(["fix", "--esper-dir", target]) }
      _code, out, _err = capture_io { EsperLint::CLI.run(["check", "--esper-dir", target]) }
      json = JSON.parse(out)
      assert_equal 0, json["checks"]["source_count_mismatches"]["total"]
      assert_equal 0, json["checks"]["duplicate_sources"]["total"]
      assert_equal 0, json["checks"]["index_drift"]["total"]
    end
  end

  def test_fix_refuses_dirty_tree
    Dir.mktmpdir do |tmp|
      target = File.join(tmp, "esper")
      FileUtils.cp_r(FIXTURE_ROOT, target)
      Dir.chdir(tmp) do
        system("git init -q")
        system("git -c user.email=a@b -c user.name=A add esper")
        system("git -c user.email=a@b -c user.name=A commit -q -m init")
        File.write(File.join(target, "pages/topics/topic-clean.md"), "modified after commit")
      end

      code, _out, err = capture_io { EsperLint::CLI.run(["fix", "--esper-dir", target]) }
      assert_equal 2, code
      err_json = JSON.parse(err)
      assert_equal "DIRTY_TREE", err_json["error"]["code"]
    end
  end
```

- [ ] **Step 2: Run test to verify it works**

```bash
bundle exec ruby -Ilib -Itest test/test_cli.rb
```

Expected: the round-trip test passes; the dirty-tree test passes.

(If they fail, the most likely cause is interaction between the in-memory `Repo` state and on-disk mutations — `run_fix` reloads the repo between phases, but the test may need to as well.)

- [ ] **Step 3: Run the full suite again**

```bash
bundle exec rake test
```

Expected: all green.

- [ ] **Step 4: standardrb + commit**

```bash
bundle exec standardrb --fix
git add test/test_cli.rb
git commit -m "test: round-trip and dirty-tree integration tests for CLI"
```

---

## Task 16: README polish + final checks

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Expand README with worked examples**

Add a section showing JSON output samples (lift verbatim from the spec) and a note on the permissions allowlist line for Synergy.

- [ ] **Step 2: Run full test suite + standardrb one final time**

```bash
bundle exec rake
```

Expected: all tests pass, standardrb clean.

- [ ] **Step 3: Manually invoke the binary against the fixture**

```bash
bin/esper-lint check --esper-dir test/fixtures/esper | jq .
bin/esper-lint sources --orphan --esper-dir test/fixtures/esper | jq '.total'
bin/esper-lint tags --threshold 3 --missing-page --esper-dir test/fixtures/esper | jq .
```

Expected: real JSON output that matches the spec shapes.

- [ ] **Step 4: Tag the release**

```bash
git tag v0.1.0
```

- [ ] **Step 5: Final commit**

```bash
git add README.md
git commit -m "docs: README with usage examples and permissions snippet"
```

---

## Self-review notes (post-write)

Spec coverage check:
- All 7 lint checks → Tasks 6-8
- All 3 safe fixes → Tasks 10-11
- All 4 query subcommands → Task 9
- `add-source` mutation → Task 12
- Git clean-tree guard → Task 13 + Task 14 (`run_fix`)
- JSON envelope shape → Task 14
- Exit codes → Task 14 (`run_check` returns 1 on findings; queries/fixes/mutations return 0; errors return 2)
- Edge cases (unicode, hash-suffix twins, stub orphans, missing source_count, empty Sources, missing Connections, malformed YAML) → fixture covers them; tests exercise them in Tasks 3-12
- `standard` linter → Task 1 sets it up; every task ends with `bundle exec standardrb --fix`
- Permissions allowlist documentation → README in Task 16

Key invariants enforced:
- After mutations, `source_count` matches actual unique link count → Tasks 10, 12
- Sources lists sorted + dedup'd → Task 10 (`dedup_sources` sorts), Task 12 (`add_source` sorts)
- `fix` is idempotent → Task 10 explicit test
- `add-source` is idempotent for already-present slugs → Task 12 explicit test

Deliberate choices vs spec:
- The CLI uses `Hash#except` (Ruby 3.0+). If the implementer's Ruby is older, the plan flags this.
- Manifest cursor parsing prefers `last_processed` over `last_sync` per spec.
- `dedup_sources` sorts the deduplicated list before writing — combined with `add-source`'s sort, this means after any mutation, every Sources list is alphabetically sorted (case-insensitive). The spec only requires post-mutation ordering for `add-source` and `fix`; this implementation is slightly stronger but consistent with the spec's intent.
