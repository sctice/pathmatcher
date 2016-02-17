require 'test/unit'
require_relative '../lib/matcher'

class TestMatcher < Test::Unit::TestCase
  def test_non_match
    assert_score 0.0000, 'a',     ''
    assert_score 0.0000, 'a',     'x'
    assert_score 0.0000, 'ab',    'ax'
    assert_score 0.0000, 'ab',    'ba'
    assert_score 0.0000, 'aaa',   'aa'
    assert_score 0.0000, 'aaa',   'axxax'
  end

  def test_single_component_match
    assert_score 1.0000, 'a',     'a'
    assert_score 0.7500, 'a',     'ax'
    assert_score 0.2812, 'a',     'xa'
    assert_score 0.6667, 'a',     'axx'
    assert_score 0.2500, 'a',     'xax'
    assert_score 0.1667, 'a',     'xxa'

    assert_score 1.0000, 'ab',    'ab'
    assert_score 0.8333, 'ab',    'abx'
    assert_score 0.5729, 'ab',    'axb'
    assert_score 0.5729, 'ab',    'xab'
    assert_score 0.7500, 'ab',    'abxx'
    assert_score 0.5156, 'ab',    'axbx'
    assert_score 0.5156, 'ab',    'xabx'
    assert_score 0.4688, 'ab',    'axxb'
    assert_score 0.2812, 'ab',    'xaxb'
    assert_score 0.4688, 'ab',    'xxab'

    assert_score 1.0000, 'abc',   'abc'
    assert_score 0.8750, 'abc',   'abcx'
    assert_score 0.6927, 'abc',   'abxc'
    assert_score 0.6927, 'abc',   'axbc'
    assert_score 0.6927, 'abc',   'xabc'
    assert_score 0.8000, 'abc',   'abcxx'
    assert_score 0.6333, 'abc',   'abxcx'
    assert_score 0.6333, 'abc',   'axbcx'
    assert_score 0.6333, 'abc',   'xabcx'
    assert_score 0.4667, 'abc',   'xabxc'
    assert_score 0.4667, 'abc',   'xaxbc'
    assert_score 0.6000, 'abc',   'xxabc'
    assert_score 0.6000, 'abc',   'abxxc'
    assert_score 0.4667, 'abc',   'axbxc'
    assert_score 0.6000, 'abc',   'axxbc'
  end

  def test_different_case_match
    assert_score 1.0000, 'a',     'A'
    assert_score 1.0000, 'A',     'a'
    assert_score 1.0000, 'aA',    'Aa'
    assert_score 1.0000, 'aa',    'Aa'
    assert_score 1.0000, 'aa',    'aA'
  end

  def test_multi_component_match
    assert_score 0.6000, 'a',     'x/a'
    assert_score 0.5400, 'a',     'x/x/a'
    assert_score 0.4800, 'a',     'x/x-a'
    assert_score 0.4800, 'a',     'x/x_a'
    assert_score 0.4800, 'a',     'x/x a'
    assert_score 0.4800, 'a',     'x/x0a'
    assert_score 0.4800, 'a',     'x/x1a'
    assert_score 0.4800, 'a',     'x/x2a'
    assert_score 0.4800, 'a',     'x/x3a'
    assert_score 0.4800, 'a',     'x/x4a'
    assert_score 0.4800, 'a',     'x/x5a'
    assert_score 0.4800, 'a',     'x/x6a'
    assert_score 0.4800, 'a',     'x/x7a'
    assert_score 0.4800, 'a',     'x/x8a'
    assert_score 0.4800, 'a',     'x/x9a'
    assert_score 0.4800, 'a',     'x/xxA'

    assert_score 0.7125, 'ab',    'x/ab'
    assert_score 0.4688, 'ab',    'a/xb'
    assert_score 0.7125, 'ab',    'a/bx'
    assert_score 0.4250, 'ab',    'xa/x/b'
    assert_score 0.6000, 'ab',    'xa/a/b'
    assert_score 0.6333, 'ab',    'a/xb/b'
  end

  # Slashes (and periods) in the query should be immune to distance
  # punishments, which might otherwise boost longer paths above shorter paths
  # for happening to have a relevant sequence right next to a path.
  def test_separator_distance_immunity
    assert_score 0.5768, 'abc/d', 'axxbcx/dxxxxxx'
    assert_score 0.5262, 'abc/d', 'axxbcx/xxxxbc/dxxxxxx'
  end

  def assert_score(s_exp, query, path, msg = nil)
    q = Matcher::Query.new(query)
    p = q.score_path(path)
    s_str = sprintf('%.4f', p.score)
    msg = build_message(msg, 'query = ?, path = ?, score = ?',
      query, path, s_str)
    assert_in_delta s_exp, p.score, 1e-4, msg
  end
end
