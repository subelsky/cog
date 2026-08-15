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

  def index_text
    File.read(File.join(FIXTURE_ROOT, "index.md"))
  end

  def manifest_fresh
    File.read(File.join(FIXTURE_ROOT, "sources/manifest-fresh.yml"))
  end

  def manifest_stale
    File.read(File.join(FIXTURE_ROOT, "sources/manifest-stale.yml"))
  end

  def manifest_opaque
    File.read(File.join(FIXTURE_ROOT, "sources/manifest-opaque.yml"))
  end

  def test_parse_manifest_cursor_returns_date_kind_and_field_for_last_processed
    cursor = EsperLint::Parsing.parse_manifest_cursor(manifest_fresh)
    assert_equal :date, cursor[:kind]
    assert_equal :last_processed, cursor[:cursor_field]
    assert_equal Date.new(2026, 5, 1), cursor[:value]
  end

  def test_parse_manifest_cursor_returns_nil_value_for_null_cursor
    cursor = EsperLint::Parsing.parse_manifest_cursor(manifest_stale)
    assert_equal :date, cursor[:kind]
    assert_equal :last_sync, cursor[:cursor_field]
    assert_nil cursor[:value]
  end

  def test_parse_manifest_cursor_recognizes_opaque_kind
    cursor = EsperLint::Parsing.parse_manifest_cursor(manifest_opaque)
    assert_equal :opaque, cursor[:kind]
    assert_equal :last_processed, cursor[:cursor_field]
    assert_equal "somesite.com_abc123def", cursor[:value]
  end

  def test_parse_manifest_cursor_defaults_kind_to_date_when_absent
    text = "cursor:\n  last_processed: 2026-04-12\n"
    cursor = EsperLint::Parsing.parse_manifest_cursor(text)
    assert_equal :date, cursor[:kind]
    assert_equal :last_processed, cursor[:cursor_field]
    assert_equal Date.new(2026, 4, 12), cursor[:value]
  end

  def test_parse_manifest_cursor_returns_date_kind_with_nil_field_when_no_cursor_block
    cursor = EsperLint::Parsing.parse_manifest_cursor("source_type: foo\n")
    assert_equal :date, cursor[:kind]
    assert_nil cursor[:cursor_field]
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

  def test_coerce_cursor_date_passes_through_date
    d = Date.new(2026, 5, 1)
    assert_equal d, EsperLint::Parsing.coerce_cursor_date(d)
  end

  def test_coerce_cursor_date_parses_iso_string
    assert_equal Date.new(2026, 5, 1), EsperLint::Parsing.coerce_cursor_date("2026-05-01")
  end

  def test_coerce_cursor_date_returns_nil_for_unparseable_string
    assert_nil EsperLint::Parsing.coerce_cursor_date("not a date")
    assert_nil EsperLint::Parsing.coerce_cursor_date("2026-13-99")
  end

  def test_coerce_cursor_date_returns_nil_for_nil
    assert_nil EsperLint::Parsing.coerce_cursor_date(nil)
  end

  def test_coerce_cursor_date_returns_nil_for_unparseable_types
    assert_nil EsperLint::Parsing.coerce_cursor_date({})
  end
end
