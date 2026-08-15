# frozen_string_literal: true

require "date"

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

    def source_count_mismatches(repo)
      items = repo.topics.filter_map do |t|
        fm_count = t.frontmatter["source_count"] || 0
        actual = t.sources_slugs.uniq.size
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

    # Returns [is_stale, age_days] for a parsed cursor.
    # Opaque cursors with non-null values are always fresh (the producer owns currency).
    # Date cursors apply the stale_days threshold; nil or unparseable values are stale.
    def classify_manifest_staleness(cursor, stale_days, today)
      case cursor[:kind]
      when :opaque
        cursor[:value].nil? ? [true, nil] : [false, nil]
      else
        date = Parsing.coerce_cursor_date(cursor[:value])
        if date.nil?
          [true, nil]
        else
          age = (today - date).to_i
          [age >= stale_days, age]
        end
      end
    end

    # Membership drift only. Count drift is reported by source_count_mismatches,
    # which derives it from disk rather than from the index table; reporting it
    # here too made one problem look like two.
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

      {total: items.size, items: items}
    end
  end
end
