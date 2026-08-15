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
    assert_equal EsperLint::VERSION, json["meta"]["tool_version"]
    assert json["checks"]["orphans"]["total"] > 0
    assert_equal 1, code
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
    assert_equal 6, json["total"]
    assert_equal 0, code
  end

  def test_tags_missing_page_uses_default_tag_threshold
    code, out, _err = capture_io do
      EsperLint::CLI.run(["tags", "--missing-page", "--esper-dir", FIXTURE_ROOT])
    end
    json = JSON.parse(out)
    tags = json["results"].map { |r| r["tag"] }
    assert_includes tags, "shared-missing-tag"
    refute_includes tags, "unique-tag-only", "subthreshold tags should not appear by default"
    assert_equal 0, code
  end

  def test_tags_tag_threshold_flag
    code, out, _err = capture_io do
      EsperLint::CLI.run(["tags", "--tag-threshold", "3", "--missing-page", "--esper-dir", FIXTURE_ROOT])
    end
    json = JSON.parse(out)
    assert(json["results"].any? { |r| r["tag"] == "shared-missing-tag" })
    assert_equal 0, code
  end

  def test_version_subcommand
    code, out, _err = capture_io { EsperLint::CLI.run(["version"]) }
    assert_includes out, EsperLint::VERSION
    assert_equal 0, code
  end

  def test_help_flag_dash_h_prints_full_help
    code, out, _err = capture_io { EsperLint::CLI.run(["-h"]) }
    assert_equal 0, code
    assert_includes out, "FOR ORCHESTRATORS"
    assert_includes out, "EXIT CODES"
  end

  def test_help_flag_double_dash_prints_full_help
    code, out, _err = capture_io { EsperLint::CLI.run(["--help"]) }
    assert_equal 0, code
    assert_includes out, "FOR ORCHESTRATORS"
  end

  def test_help_works_after_subcommand
    code, out, _err = capture_io { EsperLint::CLI.run(["sources", "--orphan", "--help"]) }
    assert_equal 0, code
    assert_includes out, "FOR ORCHESTRATORS"
  end

  def test_version_flag_dash_v_prints_version
    code, out, _err = capture_io { EsperLint::CLI.run(["-v"]) }
    assert_equal 0, code
    assert_includes out, EsperLint::VERSION
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

  def test_fix_subcommand_is_gone
    code, _out, err = capture_io { EsperLint::CLI.run(["fix", "--esper-dir", FIXTURE_ROOT]) }
    assert_equal 2, code
    err_json = JSON.parse(err)
    assert_equal "INVALID_ARGUMENT", err_json["error"]["code"]
    assert_includes err_json["error"]["message"], "fix"
  end

  def test_add_source_subcommand_is_gone
    code, _out, err = capture_io do
      EsperLint::CLI.run(["add-source", "topic-clean", "source-fixable-orphan", "--esper-dir", FIXTURE_ROOT])
    end
    assert_equal 2, code
    err_json = JSON.parse(err)
    assert_equal "INVALID_ARGUMENT", err_json["error"]["code"]
    assert_includes err_json["error"]["message"], "add-source"
  end

  def test_check_default_output_has_no_items
    _code, out, _err = capture_io { EsperLint::CLI.run(["check", "--esper-dir", FIXTURE_ROOT]) }
    json = JSON.parse(out)
    json["checks"].each do |name, check|
      refute check.key?("items"), "#{name} should not carry items without --detail"
    end
  end

  def test_check_keeps_scalar_fields_without_detail
    _code, out, _err = capture_io { EsperLint::CLI.run(["check", "--esper-dir", FIXTURE_ROOT]) }
    checks = JSON.parse(out)["checks"]
    assert_equal 6, checks["orphans"]["total"]
    assert_equal({"stub" => 1, "fixable" => 1, "subthreshold" => 4}, checks["orphans"]["by_class"])
    assert_equal 3, checks["missing_topic_candidates"]["threshold"]
    assert_equal 30, checks["stale_manifests"]["stale_days_threshold"]
  end

  def test_detail_attaches_items_to_one_check_only
    _code, out, _err = capture_io do
      EsperLint::CLI.run(["check", "--detail", "orphans", "--esper-dir", FIXTURE_ROOT])
    end
    checks = JSON.parse(out)["checks"]
    assert checks["orphans"].key?("items")
    assert_equal 6, checks["orphans"]["items"].size
    refute checks["orphans"].key?("items_truncated")
    checks.each do |name, check|
      next if name == "orphans"
      refute check.key?("items"), "#{name} should stay summary-only"
    end
  end

  def test_limit_truncates_detail_items
    _code, out, _err = capture_io do
      EsperLint::CLI.run(["check", "--detail", "orphans", "--limit", "2", "--esper-dir", FIXTURE_ROOT])
    end
    orphans = JSON.parse(out)["checks"]["orphans"]
    assert_equal 2, orphans["items"].size
    assert_equal true, orphans["items_truncated"]
    assert_equal 2, orphans["items_shown"]
    assert_equal 6, orphans["total"], "total must still report every finding"
  end

  def test_unknown_detail_check_returns_2
    code, _out, err = capture_io do
      EsperLint::CLI.run(["check", "--detail", "bogus", "--esper-dir", FIXTURE_ROOT])
    end
    assert_equal 2, code
    err_json = JSON.parse(err)
    assert_equal "INVALID_ARGUMENT", err_json["error"]["code"]
  end

  def test_meta_has_no_ran_at
    _code, out, _err = capture_io { EsperLint::CLI.run(["check", "--esper-dir", FIXTURE_ROOT]) }
    meta = JSON.parse(out)["meta"]
    refute meta.key?("ran_at")
    assert_equal EsperLint::VERSION, meta["tool_version"]
  end

  def test_query_subcommands_still_return_full_results
    _code, out, _err = capture_io { EsperLint::CLI.run(["sources", "--orphan", "--esper-dir", FIXTURE_ROOT]) }
    json = JSON.parse(out)
    assert_equal 6, json["results"].size
  end
end
