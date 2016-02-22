module PathMatcher
  VERSION = '0.1.0'
end

require_relative 'pathmatcher/query'
require_relative 'pathmatcher/cli'

begin
  require_relative '../ext/pathmatchc'
  PathMatcher::PathMatch = PathMatcher::PathMatchC
rescue LoadError
  require_relative 'pathmatcher/pathmatchpure'
  PathMatcher::PathMatch = PathMatcher::PathMatchPure
end
