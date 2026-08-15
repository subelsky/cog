# frozen_string_literal: true

module EsperLint
  TopicRecord = Struct.new(:slug, :path, :frontmatter, :l0, :sources_slugs, :has_connections, :raw_text, keyword_init: true)
  SourceRecord = Struct.new(:slug, :path, :frontmatter, :topics, keyword_init: true)
  ManifestRecord = Struct.new(:filename, :path, :cursor, keyword_init: true)

  class Repo
    attr_reader :esper_dir, :topics, :sources, :manifests, :index_rows, :warnings, :malformed_paths

    def initialize(esper_dir)
      @esper_dir = Pathname.new(esper_dir).expand_path
      unless @esper_dir.directory?
        raise Error.new(code: :ESPER_DIR_MISSING, message: "esper-dir not found: #{esper_dir}", path: esper_dir.to_s)
      end

      index_path = @esper_dir.join("index.md")
      unless index_path.file?
        raise Error.new(code: :INDEX_MISSING, message: "index.md not found at #{index_path}", path: index_path.to_s)
      end

      @warnings = []
      @malformed_paths = Set.new
      @topics = load_topics
      @sources = load_sources
      @manifests = load_manifests
      @index_rows = Parsing.parse_index_table(File.read(index_path, encoding: Encoding::UTF_8))
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

    def malformed?(path)
      @malformed_paths.include?(File.expand_path(path.to_s))
    end

    private

    def load_topics
      glob = @esper_dir.join("pages/topics/*.md")
      Dir[glob.to_s].sort.map do |path|
        text = File.read(path, encoding: Encoding::UTF_8)
        slug = File.basename(path, ".md")
        fm = safe_parse_frontmatter(text, path)
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
        text = File.read(path, encoding: Encoding::UTF_8)
        slug = File.basename(path, ".md")
        fm = safe_parse_frontmatter(text, path)
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
        text = File.read(path, encoding: Encoding::UTF_8)
        cursor = begin
          Parsing.parse_manifest_cursor(text)
        rescue Psych::Exception => e
          @warnings << {warning: "malformed_manifest", path: path, message: e.message}
          {kind: :date, cursor_field: nil, value: nil}
        end
        warn_if_unparseable_cursor(cursor, path)
        ManifestRecord.new(filename: File.basename(path), path: Pathname.new(path), cursor: cursor)
      end
    end

    def warn_if_unparseable_cursor(cursor, path)
      # Opaque cursors are arbitrary producer-defined position pointers; do not
      # try to parse them as dates and do not warn.
      return if cursor[:kind] == :opaque

      value = cursor[:value]
      return if value.nil?
      return if Parsing.coerce_cursor_date(value)

      @warnings << {warning: "unparseable_cursor_date", path: path, value: value.to_s}
    end

    def safe_parse_frontmatter(text, path)
      Parsing.parse_frontmatter(text)
    rescue Error => e
      @malformed_paths << File.expand_path(path)
      @warnings << {warning: "malformed_frontmatter", path: path, message: e.message}
      {}
    end

    def build_references_cache
      @references_cache = Hash.new { |h, k| h[k] = [] }
      @topics.each do |t|
        t.sources_slugs.each { |s| @references_cache[s] << t.slug }
      end
    end
  end
end
