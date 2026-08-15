# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "esper_lint"

FIXTURE_ROOT = File.expand_path("fixtures/esper", __dir__)

module EsperLintTestHelpers
  def with_tmp_esper
    Dir.mktmpdir do |tmp|
      target = File.join(tmp, "esper")
      FileUtils.cp_r(FIXTURE_ROOT, target)
      yield target
    end
  end
end

Minitest::Test.include(EsperLintTestHelpers)
