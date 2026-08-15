# frozen_string_literal: true

require "optparse"
require "json"
require "date"

module EsperLint
  module CLI
    SUBCOMMANDS = %w[check sources topics tags manifests help version].freeze

    CHECK_NAMES = %w[
      orphans source_count_mismatches missing_topic_candidates missing_connections
      stale_manifests index_drift duplicate_sources
    ].freeze

    DEFAULT_DETAIL_LIMIT = 50

    module_function

    def run(argv)
      argv = argv.dup

      # Intercept help/version flags before subcommand dispatch so they work
      # in any position (esper-lint -h, esper-lint --help, esper-lint help,
      # esper-lint sources --help, etc.) and bypass OptionParser's terse
      # auto-generated usage.
      if argv.intersect?(%w[-h --help]) || argv.first == "help"
        print_help((argv.first == "help") ? argv[1] : nil)
        return 0
      end
      if argv.intersect?(%w[-v --version]) || argv.first == "version"
        puts "esper-lint #{EsperLint::VERSION}"
        return 0
      end

      subcommand = (argv.first && !argv.first.start_with?("-")) ? argv.shift : "check"
      subcommand = "check" if subcommand.nil? || subcommand.empty?

      unless SUBCOMMANDS.include?(subcommand)
        emit_error(:INVALID_ARGUMENT, "unknown subcommand: #{subcommand}")
        return 2
      end

      options = {
        esper_dir: "./esper",
        tag_threshold: 3,
        stale_days: 30,
        limit: DEFAULT_DETAIL_LIMIT
      }
      parse_options(subcommand, argv, options)

      repo = Repo.new(options[:esper_dir])
      emit_warnings(repo)

      meta = build_meta(options[:esper_dir], subcommand)
      payload, exit_code = dispatch(subcommand, repo, options)

      puts JSON.generate(meta.merge(payload))
      exit_code
    rescue Error => e
      emit_error(e.code, e.message, path: e.path, details: e.details)
      2
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      emit_error(:INVALID_ARGUMENT, e.message)
      2
    end

    def parse_options(subcommand, argv, options)
      parser = OptionParser.new do |o|
        o.on("--esper-dir PATH") { |v| options[:esper_dir] = v }
        o.on("--tag-threshold N", Integer) { |v| options[:tag_threshold] = v }
        o.on("--stale-days N", Integer) { |v| options[:stale_days] = v }

        case subcommand
        when "check"
          o.on("--detail CHECK") { |v| options[:detail] = v }
          o.on("--limit N", Integer) { |v| options[:limit] = v }
        when "sources"
          o.on("--orphan") { options[:orphan] = true }
          o.on("--fixable") { options[:fixable] = true }
          o.on("--tag TAG") { |v| options[:tag] = v }
          o.on("--topic SLUG") { |v| options[:topic] = v }
        when "topics"
          o.on("--count-mismatch") { options[:count_mismatch] = true }
          o.on("--missing-connections") { options[:missing_connections] = true }
        when "tags"
          o.on("--missing-page") { options[:missing_page] = true }
        when "manifests"
          o.on("--stale") { options[:stale] = true }
        end
      end
      parser.parse!(argv)
    end

    # No timestamp: it changes on every invocation, defeating prompt caching for
    # otherwise-identical calls, and tells the caller nothing it doesn't know.
    def build_meta(esper_dir, subcommand)
      {
        "meta" => {
          "esper_dir" => File.expand_path(esper_dir),
          "tool_version" => EsperLint::VERSION,
          "subcommand" => subcommand
        }
      }
    end

    def dispatch(subcommand, repo, options)
      case subcommand
      when "check"
        run_check(repo, options)
      when "sources"
        run_sources(repo, options)
      when "topics"
        run_topics(repo, options)
      when "tags"
        run_tags(repo, options)
      when "manifests"
        run_manifests(repo, options)
      end
    end

    def run_check(repo, options)
      detail = validate_detail(options[:detail])

      results = {
        "orphans" => Checks.orphans(repo),
        "source_count_mismatches" => Checks.source_count_mismatches(repo),
        "missing_topic_candidates" => Checks.missing_topic_candidates(repo, threshold: options[:tag_threshold]),
        "missing_connections" => Checks.missing_connections(repo),
        "stale_manifests" => Checks.stale_manifests(repo, stale_days: options[:stale_days]),
        "index_drift" => Checks.index_drift(repo),
        "duplicate_sources" => Checks.duplicate_sources(repo)
      }

      total_findings = results.values.sum { |v| v[:total] || 0 }
      payload = {
        "summary" => summary(repo).merge(
          "checks_with_findings" => results.values.count { |v| (v[:total] || 0) > 0 }
        ),
        "checks" => results.to_h { |name, result| [name, present_check(result, detail == name, options[:limit])] }
      }
      [normalize_keys(payload), total_findings.zero? ? 0 : 1]
    end

    def validate_detail(detail)
      return nil if detail.nil?
      return detail if CHECK_NAMES.include?(detail)

      raise Error.new(
        code: :INVALID_ARGUMENT,
        message: "unknown check for --detail: #{detail}",
        details: {known_checks: CHECK_NAMES}
      )
    end

    # Checks compute their full item lists; only --detail lets one of them out.
    # Scalars (total, by_class, threshold, stale_days_threshold) always survive.
    def present_check(result, detailed, limit)
      scalars = result.except(:items)
      return scalars unless detailed

      items = result[:items] || []
      shown = items.first(limit)
      return scalars.merge(items: shown) if shown.size == items.size

      scalars.merge(items: shown, items_truncated: true, items_shown: shown.size)
    end

    def run_sources(repo, options)
      result = Queries.sources(repo,
        orphan: options[:orphan] || false,
        fixable: options[:fixable] || false,
        tag: options[:tag],
        topic: options[:topic])
      [normalize_keys({"filters" => filter_summary(options, [:orphan, :fixable, :tag, :topic])}.merge(result)), 0]
    end

    def run_topics(repo, options)
      result = Queries.topics(repo,
        count_mismatch: options[:count_mismatch] || false,
        missing_connections: options[:missing_connections] || false)
      [normalize_keys({"filters" => filter_summary(options, [:count_mismatch, :missing_connections])}.merge(result)), 0]
    end

    def run_tags(repo, options)
      threshold = options[:tag_threshold]
      result = Queries.tags(repo, threshold: threshold, missing_page: options[:missing_page] || false)
      [normalize_keys({"filters" => {"threshold" => threshold, "missing_page" => options[:missing_page] || false}}.merge(result)), 0]
    end

    def run_manifests(repo, options)
      result = Queries.manifests(repo, stale: options[:stale] || false, stale_days: options[:stale_days])
      [normalize_keys({"filters" => filter_summary(options, [:stale])}.merge(result)), 0]
    end

    def summary(repo)
      {
        "topics" => repo.topics.size,
        "sources" => repo.sources.size,
        "manifests" => repo.manifests.size,
        "checks_with_findings" => 0
      }
    end

    def filter_summary(options, keys)
      keys.to_h { |k| [k.to_s, options[k] || false] }
    end

    def normalize_keys(obj)
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

    def emit_warnings(repo)
      repo.warnings.each { |w| warn JSON.generate(w) }
    end

    def emit_error(code, message, path: nil, details: {})
      warn JSON.generate(error: {code: code.to_s, message: message, path: path, details: details}.compact)
    end

    def print_help(_subcommand_name)
      puts <<~USAGE
        esper-lint #{EsperLint::VERSION} — deterministic, read-only lint and query tool for an Esper knowledge base.

        ─── FOR ORCHESTRATORS (CLAUDE / AGENTS) ───────────────────────────────────────

        WHAT THIS IS
          A deterministic CLI for an "Esper" knowledge base — a directory tree of
          Markdown topic pages and source pages with YAML frontmatter, plus a top-level
          index.md and per-source manifests. Use it INSTEAD of writing inline
          bash / awk / sed / python every time you need to count or list something in
          the knowledge base. Every subcommand emits JSON to stdout, warnings as JSONL
          to stderr. Pipe to jq.

          READ-ONLY. No subcommand writes to disk. Fixes are yours to make with Edit.

        EXPECTED LAYOUT (--esper-dir defaults to ./esper)
          <esper>/index.md                       — top-level table of all topics
          <esper>/pages/topics/<slug>.md         — topic page (synthesis + ## Sources + ## Connections)
          <esper>/pages/sources/<slug>.md        — source page (frontmatter has topics: [...])
          <esper>/sources/<name>.{yml,yaml}      — per-source manifest with cursor: { last_processed | last_sync }

        WHEN TO REACH FOR THIS TOOL
          ✓ "How many orphan source pages are there?" → sources --orphan
          ✓ "Which orphans could be slotted into existing topics?" → sources --orphan --fixable
          ✓ "What tags appear ≥3 times but have no topic page?" → tags --missing-page    (uses --tag-threshold, default 3)
          ✓ "Which topics' source_count drifted from the actual link count?" → topics --count-mismatch
          ✓ "Which topics are missing a Connections section?" → topics --missing-connections
          ✓ "Are any source manifests stale?" → manifests --stale
          ✓ "Run all the standard lint checks." → check
          ✓ "Show me the actual findings for one check." → check --detail orphans
          ✗ "Decide which topic an orphan belongs to." → JUDGMENT — do NOT delegate to this tool
          ✗ "Write a synthesis." → JUDGMENT
          ✗ "Add a Connections section." → JUDGMENT (hand-edit)
          ✗ "Fix the drift for me." → the tool never writes; Edit the file yourself

        EXIT CODES
          0  success (clean lint, query returned)
          1  `check` only — one or more findings present
          2  error (missing dir, malformed input, bad argument)

        OUTPUT CONTRACT
          • stdout: a single JSON object per invocation, always with a "meta" envelope
            ({esper_dir, tool_version, subcommand}) plus the subcommand-specific payload.
          • stderr: zero or more JSONL warning objects ({warning, path, message}), then —
            on error — a single JSON {error: {code, message, path?, details?}}.
          • Treat stdout as machine-readable. Parse with jq, do NOT regex it.

        ─── SUBCOMMANDS ───────────────────────────────────────────────────────────────

          check [--detail CHECK]         Run all 7 lint checks. Default subcommand. COUNTS ONLY —
                [--limit N]              each check returns its scalars (total, by_class, threshold,
                                         stale_days_threshold) and withholds its items array.
                                         Payload: { summary, checks: { orphans, source_count_mismatches,
                                         missing_topic_candidates, missing_connections, stale_manifests,
                                         index_drift, duplicate_sources } }. Exit 1 if any check has findings.
            --detail CHECK                 Also return `items` for that ONE check (name as it appears
                                           under "checks"). Unknown name → exit 2 / INVALID_ARGUMENT.
            --limit N                      Cap the returned items (default 50). When capped, the check
                                           object also carries items_truncated: true and items_shown: N —
                                           narrow with a query subcommand rather than raising the limit.

          sources [filters]              List source pages.
            --orphan                       Only sources NOT linked from any topic page's ## Sources.
            --fixable                      (Combine with --orphan) Only orphans whose `topics:` frontmatter
                                           includes at least one existing topic slug — these are the
                                           "easy wins" to add by hand to that topic's ## Sources list.
            --tag TAG                      Only sources whose frontmatter `topics:` array contains TAG.
            --topic SLUG                   Only sources currently linked from that topic.

          topics [filters]               List topic pages.
            --count-mismatch               Only topics where frontmatter source_count ≠ unique link count.
            --missing-connections          Only topics with no `## Connections` section.

          tags [filters]                 List tag frequency from source frontmatter.
            --missing-page                 Only tags with no matching pages/topics/<tag>.md.
                                           Threshold comes from --tag-threshold (default 3) — combine
                                           with --missing-page to surface topic candidates.

          manifests [filters]            List source manifests with cursor freshness.
            --stale                        Only stale manifests (null cursor or age ≥ --stale-days).

          The four query subcommands above are the intended path for "show me the actual
          items" — they are filtered by their own flags and return full `results`.

          version                        Print version and exit 0.
          help                           Print this message and exit 0.

        ─── GLOBAL OPTIONS ────────────────────────────────────────────────────────────

          --esper-dir PATH               Path to the esper directory (default: ./esper).
          --tag-threshold N              Default minimum tag frequency for missing-topic candidates
                                         in `check` (default: 3).
          --stale-days N                 Manifest age threshold in days for `check` and `manifests`
                                         (default: 30).

        ─── ERROR CODES (stderr error envelope) ───────────────────────────────────────

          ESPER_DIR_MISSING        --esper-dir doesn't exist or isn't a directory.
          INDEX_MISSING            <esper>/index.md not found.
          MALFORMED_FRONTMATTER    A required file's YAML frontmatter failed to parse.
          INVALID_ARGUMENT         Conflicting flags, unknown --detail check, unknown subcommand, etc.

        ─── EXAMPLES ──────────────────────────────────────────────────────────────────

          # The lint sweep — what's broken / what needs attention
          esper-lint check | jq '.checks | to_entries | map(select(.value.total > 0))'

          # Drill into one check once the sweep says it has findings
          esper-lint check --detail source_count_mismatches | jq '.checks.source_count_mismatches.items'

          # Fixable orphans — orphans whose tag points at an existing topic page
          esper-lint sources --orphan --fixable | jq '.results[] | {slug, matching_topics}'

          # Hot tags missing a topic page (candidates for new topic creation)
          esper-lint tags --threshold 3 --missing-page | jq '.results[] | "\\(.tag): \\(.count)"'
      USAGE
    end
  end
end
