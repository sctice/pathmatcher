module Matcher
  class Query
    attr_reader :query, :query_len

    def self.build(query)
      self.new(query, Matcher::PathMatch)
    end

    def initialize(query, pathmatch_class)
      @query = query.downcase
      @query_len = @query.length
      @pathmatch_class = pathmatch_class
    end

    def score_path(path)
      @pathmatch_class.new(path, self)
    end
  end
end
