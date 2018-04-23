require 'stringio'

class TestPathMatcherCLI < Minitest::Unit::TestCase
  def setup
    @paths = [
      {:path => 'x/x1a', :score =>  4800},
      {:path => 'x/x2a', :score =>  4800},
      {:path => 'x/x3b', :score =>     0},
      {:path => 'x/x4a', :score =>  4800},
      {:path => 'x/x5a', :score =>  4800},
      {:path => 'a',     :score => 10000}
    ]
    @matches = @paths.select {|p| p[:score] > 0}.sort_by do |p|
      [-p[:score], p[:path]]
    end
    @argf = StringIO.new(@paths.map {|p| p[:path]}.join("\n") + "\n", 'r')
    @stdout = StringIO.new
  end

  def test_basic_usage
    PathMatcher.invoke(['a'], @argf, @stdout)
    expected_lines = @matches.map {|p| p[:path]}.join("\n") + "\n"
    out_lines = @stdout.string
    assert_equal expected_lines, out_lines
  end

  def test_limit
    PathMatcher.invoke(['-l2', 'a'], @argf, @stdout)
    expected_lines = @matches.take(2).map {|p| p[:path]}.join("\n") + "\n"
    out_lines = @stdout.string
    assert_equal expected_lines, out_lines
  end

  def test_print_scores
    PathMatcher.invoke(['-s', 'a'], @argf, @stdout)
    with_scores = @matches.map do |p|
      sprintf("%5d %s\n", p[:score], p[:path])
    end
    expected_lines = with_scores.join('')
    out_lines = @stdout.string
    assert_equal expected_lines, out_lines
  end

  def test_unsorted
    PathMatcher.invoke(['-u', 'a'], @argf, @stdout)
    unsorted_matches = @paths.select {|p| p[:score] > 0}
    expected_lines = unsorted_matches.map {|p| p[:path]}.join("\n") + "\n"
    out_lines = @stdout.string
    assert_equal expected_lines, out_lines
  end

  def test_help
    e = assert_raises PathMatcher::Help do
      PathMatcher.invoke(['-h'], @argf, @stdout)
    end
    assert_match /^usage:/, e.message
  end

  def test_missing_query
    e = assert_raises PathMatcher::ParseError do
      PathMatcher.invoke([], @argf, @stdout)
    end
    assert_match /missing mandatory query/, e.message
  end

  def test_invalid_flag
    e = assert_raises PathMatcher::ParseError do
      PathMatcher.invoke(['--no-such-flag', 'a'], @argf, @stdout)
    end
    assert_match /^invalid option: --no-such-flag/, e.message
  end
end
