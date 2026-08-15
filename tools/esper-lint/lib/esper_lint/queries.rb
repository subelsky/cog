# frozen_string_literal: true

require "date"

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
        is_stale, age_days = Checks.classify_manifest_staleness(cursor, stale_days, today)
        {
          file: m.filename,
          cursor_kind: cursor[:kind].to_s,
          cursor_field: cursor[:cursor_field]&.to_s,
          value: cursor[:value].is_a?(Date) ? cursor[:value].to_s : cursor[:value],
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
