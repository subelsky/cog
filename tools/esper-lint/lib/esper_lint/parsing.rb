# frozen_string_literal: true

require "yaml"
require "date"

module EsperLint
  module Parsing
    FRONTMATTER_RE = /\A(?:<!--.*?-->\s*\n)*---\s*\n(.*?)\n---\s*\n?/m
    L0_RE = /\A<!--\s*L0:\s*(.*?)\s*-->\s*\z/
    SOURCE_LINK_RE = /^-\s*\[\[pages\/sources\/(.+?)\]\]\s*$/
    INDEX_ROW_RE = /^\|\s*\[\[pages\/topics\/([^\]]+)\]\]\s*\|\s*(\d+)\s*\|\s*([\d-]+)\s*\|\s*(.*?)\s*\|\s*$/

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

    # Parses a manifest's top-level `cursor:` block.
    #
    # Returns: { kind:, cursor_field:, value: }
    #   kind         — :date (default) | :opaque. Discriminator from cursor.kind.
    #   cursor_field — :last_processed | :last_sync | nil. Which key carried the value.
    #   value        — the raw value as YAML parsed it (Date, String, or nil).
    #
    # Callers apply kind-specific logic: for :date, coerce_cursor_date(value) and
    # treat nil-from-coerce as "unparseable" (typically warn + stale). For :opaque,
    # treat any non-nil value as a fresh, opaque position pointer.
    #
    # Backward compatibility: manifests without an explicit `kind:` default to :date
    # so v0.1.x behavior is preserved.
    def parse_manifest_cursor(text)
      data = YAML.safe_load(text, permitted_classes: [Date, Time, Symbol]) || {}
      cursor_block = data["cursor"]
      return {kind: :date, cursor_field: nil, value: nil} unless cursor_block.is_a?(Hash)

      kind = (cursor_block["kind"] || "date").to_s.to_sym
      cursor_field = if cursor_block.key?("last_processed")
        :last_processed
      elsif cursor_block.key?("last_sync")
        :last_sync
      end
      value = cursor_field ? cursor_block[cursor_field.to_s] : nil

      {kind: kind, cursor_field: cursor_field, value: value}
    end

    # Best-effort Date coercion for cursor values. Returns the value if it is
    # already a Date, nil if the value is nil or unparseable, otherwise a
    # parsed Date. Unparseable strings are silently downgraded to nil so the
    # caller can treat them as "no usable date" (typically: stale).
    def coerce_cursor_date(value)
      return nil if value.nil?
      return value if value.is_a?(Date)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      # Date::Error is an ArgumentError subclass, so it's covered above.
      nil
    end

    def parse_index_table(text)
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
  end
end
