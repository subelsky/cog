# frozen_string_literal: true

# Force UTF-8 for file I/O. The container locale may default to US-ASCII,
# which breaks reads of source pages whose slugs contain unicode characters.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Ruby 4.x default-loads both of these; Ruby 3.x does not. repo.rb uses
# Pathname and Set, so they must be required explicitly or the tool raises
# NameError on its first call under 3.x. Do not remove.
require "pathname"
require "set"

require_relative "esper_lint/version"
require_relative "esper_lint/error"
require_relative "esper_lint/parsing"
require_relative "esper_lint/repo"
require_relative "esper_lint/checks"
require_relative "esper_lint/queries"
require_relative "esper_lint/cli"

module EsperLint
end
