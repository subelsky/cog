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
    # 6 orphans: source-stub-twin-9359a1, source-fixable-orphan,
    #   source-subthreshold-orphan, source-shared-tag-{1,2,3}.
    # source-stub is referenced from topic-duplicate-sources, NOT an orphan.
    result = EsperLint::Queries.sources(repo, orphan: true)
    slugs = result[:results].map { |r| r[:slug] }
    assert_equal 6, result[:total]
    assert_includes slugs, "source-stub-twin-9359a1"
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

  def test_manifests_includes_opaque_in_unfiltered_listing
    result = EsperLint::Queries.manifests(repo, stale_days: 30, today: Date.new(2026, 5, 5))
    files = result[:results].map { |r| r[:file] }
    assert_includes files, "manifest-opaque.yml"
    opaque = result[:results].find { |r| r[:file] == "manifest-opaque.yml" }
    assert_equal "opaque", opaque[:cursor_kind]
    assert_equal "last_processed", opaque[:cursor_field]
    assert_equal "somesite.com_abc123def", opaque[:value]
    refute opaque[:is_stale], "opaque-kind cursor with non-null value should not be flagged stale"
  end

  def test_manifests_emits_cursor_kind_and_cursor_field_for_date
    result = EsperLint::Queries.manifests(repo, stale_days: 30, today: Date.new(2026, 5, 5))
    fresh = result[:results].find { |r| r[:file] == "manifest-fresh.yml" }
    refute_nil fresh
    assert_equal "date", fresh[:cursor_kind]
    assert_equal "last_processed", fresh[:cursor_field]
  end
end
