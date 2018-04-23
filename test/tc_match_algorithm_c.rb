require_relative 'tc_match_algorithm'

class TestPathMatchAlgorithmC < TestPathMatchAlgorithm
  def setup
    have_c_ext = defined? PathMatcher::PathMatchC
    skip 'PathMatchC extension not built?' unless have_c_ext
    @path_match = PathMatcher::PathMatchC
  end
end
