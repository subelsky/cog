# frozen_string_literal: true

module EsperLint
  class Error < StandardError
    attr_reader :code, :path, :details

    def initialize(code:, message:, path: nil, details: {})
      super(message)
      @code = code
      @path = path
      @details = details
    end
  end
end
