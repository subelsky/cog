# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

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
    assert_equal 3, repo.manifests.size
  end

  def test_load_manifests_does_not_warn_for_opaque_cursor
    refute(repo.warnings.any? { |w| w[:warning] == "unparseable_cursor_date" },
      "opaque-kind cursors must not trigger unparseable_cursor_date warning")
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

  def test_load_manifests_warns_on_malformed_yaml_only
    with_tmp_esper do |dir|
      File.write(File.join(dir, "sources/broken.yml"), "cursor: : not_yaml\n")
      r = EsperLint::Repo.new(dir)
      assert(r.warnings.any? { |w| w[:warning] == "malformed_manifest" && w[:path].end_with?("broken.yml") })
    end
  end

  def test_load_manifests_warns_on_unparseable_cursor_date
    with_tmp_esper do |dir|
      File.write(File.join(dir, "sources/garbage-date.yml"), <<~YAML)
        cursor:
          last_processed: "not a date"
      YAML
      r = EsperLint::Repo.new(dir)
      w = r.warnings.find { |x| x[:warning] == "unparseable_cursor_date" }
      refute_nil w, "expected an unparseable_cursor_date warning"
      assert w[:path].end_with?("garbage-date.yml")
      assert_equal "not a date", w[:value]
    end
  end
end
