# frozen_string_literal: true

require_relative "test_helper"

class TestChecks < Minitest::Test
  def repo
    @repo ||= EsperLint::Repo.new(FIXTURE_ROOT)
  end

  def test_orphans_returns_total_and_by_class
    # Orphan inventory:
    #   stub: source-stub-twin-9359a1 (source-stub itself is referenced from
    #     topic-duplicate-sources, so NOT an orphan).
    #   fixable: source-fixable-orphan.
    #   subthreshold: source-subthreshold-orphan + source-shared-tag-{1,2,3}.
    result = EsperLint::Checks.orphans(repo)
    assert_equal 6, result[:total]
    assert_equal({stub: 1, fixable: 1, subthreshold: 4}, result[:by_class])
  end

  def test_orphans_classifies_stubs
    result = EsperLint::Checks.orphans(repo)
    stub = result[:items].find { |i| i[:slug] == "source-stub-twin-9359a1" }
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
    refute_includes tags, "topic-clean"
  end

  def test_stale_manifests_default
    result = EsperLint::Checks.stale_manifests(repo, stale_days: 30, today: Date.new(2026, 5, 5))
    assert_equal 30, result[:stale_days_threshold]
    items = result[:items]
    stale = items.find { |i| i[:file] == "manifest-stale.yml" }
    refute_nil stale
    assert_nil stale[:age_days]
    refute items.any? { |i| i[:file] == "manifest-fresh.yml" }
    refute items.any? { |i| i[:file] == "manifest-opaque.yml" },
      "opaque-kind cursor with non-null value must not be reported as stale"
  end

  def test_stale_manifests_includes_aged_dates
    result = EsperLint::Checks.stale_manifests(repo, stale_days: 1, today: Date.new(2026, 5, 5))
    fresh = result[:items].find { |i| i[:file] == "manifest-fresh.yml" }
    refute_nil fresh
    assert_equal 4, fresh[:age_days]
    assert_equal "date", fresh[:cursor_kind]
    assert_equal "last_processed", fresh[:cursor_field]
  end

  def test_stale_manifests_opaque_with_value_is_fresh_even_at_threshold_1
    # Opaque cursors don't have an age; they should never be reported as stale
    # while the value is non-null, regardless of how aggressive --stale-days is.
    result = EsperLint::Checks.stale_manifests(repo, stale_days: 1, today: Date.new(2026, 5, 5))
    refute result[:items].any? { |i| i[:file] == "manifest-opaque.yml" }
  end

  def test_stale_manifests_opaque_with_null_value_is_stale
    with_tmp_esper do |dir|
      File.write(File.join(dir, "sources/manifest-opaque-null.yml"), <<~YAML)
        cursor:
          kind: opaque
          last_processed: null
      YAML
      r = EsperLint::Repo.new(dir)
      result = EsperLint::Checks.stale_manifests(r, stale_days: 30, today: Date.new(2026, 5, 5))
      stale = result[:items].find { |i| i[:file] == "manifest-opaque-null.yml" }
      refute_nil stale, "opaque cursor with null value should be reported as stale"
      assert_equal "opaque", stale[:cursor_kind]
      assert_nil stale[:age_days]
    end
  end

  def test_stale_manifests_handles_unparseable_date_string
    with_tmp_esper do |dir|
      File.write(File.join(dir, "sources/garbage.yml"), <<~YAML)
        cursor:
          last_processed: "not a date"
      YAML
      r = EsperLint::Repo.new(dir)
      result = EsperLint::Checks.stale_manifests(r, stale_days: 30, today: Date.new(2026, 5, 5))
      stale = result[:items].find { |i| i[:file] == "garbage.yml" }
      refute_nil stale, "manifest with unparseable date should be reported as stale, not crash"
      assert_nil stale[:age_days]
    end
  end

  def test_index_drift_reports_membership_only
    # Every fixture topic is listed in index.md and every index row has a page,
    # so there is no membership drift. Count drift is source_count_mismatches'
    # job and must not be double-reported here.
    result = EsperLint::Checks.index_drift(repo)
    assert_equal 0, result[:total]
    assert_empty result[:items]
  end

  def test_index_drift_reports_missing_and_extra_topics
    with_tmp_esper do |dir|
      File.write(File.join(dir, "pages/topics/topic-unindexed.md"), <<~MD)
        ---
        source_count: 0
        ---

        # Unindexed

        ## Sources

        ## Connections
      MD
      File.delete(File.join(dir, "pages/topics/topic-empty.md"))

      result = EsperLint::Checks.index_drift(EsperLint::Repo.new(dir))
      kinds = result[:items].to_h { |i| [i[:topic], i[:kind]] }
      assert_equal :missing_from_index, kinds["topic-unindexed"]
      assert_equal :extra_in_index, kinds["topic-empty"]
      assert_equal 2, result[:total]
    end
  end
end
