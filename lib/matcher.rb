module Matcher
  VERSION = '0.1.0'
end

require_relative 'matcher/query'
require_relative 'matcher/cli'

begin
  require_relative '../ext/pathmatchc'
  Matcher::PathMatch = Matcher::PathMatchC
rescue LoadError
  require_relative 'matcher/pathmatchpure'
  Matcher::PathMatch = Matcher::PathMatchPure
end
