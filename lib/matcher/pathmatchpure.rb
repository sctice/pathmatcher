require 'set'

module Matcher
  WORDBREAK_CHARS = Set['-', '_', ' '] + ('0'..'9')
  LOWER = ('a'..'z')
  UPPER = ('A'..'Z')

  class PathMatchPure
    attr_reader :path, :score

    def initialize(path, q)
      @path = path
      @path_len = path.length()
      @max_score_per_char = (1.0 / @path_len + 1.0 / q.query_len) / 2.0
      @char_rxs = Hash.new do |h, c|
        h[c] = Regexp.new(Regexp.escape(c), Regexp::IGNORECASE)
      end
      @offsets = Hash.new do |h, c|
        os = []
        @path.scan(@char_rxs[c]) {|x| os << $~.offset(0)[0]}
        h[c] = os
      end
      @score =
        case
        when q.query_len < @path_len
          self.compute_subscore(q)
        when q.query_len > @path_len
          0.0
        else
          @path.casecmp(q.query) == 0 ? 1.0 : 0.0
        end
    end

    def compute_subscore(q, query_beg = 0, path_beg = 0, last_path_pos = -1)
      best_score = 0.0
      score = 0.0
      for query_pos in query_beg...q.query_len
        qc = q.query[query_pos]
        path_pos, next_path_pos = self.find_next_matches(qc, path_beg)
        return 0.0 if path_pos.nil?
        pc = @path[path_pos]
        pc_score = @max_score_per_char
        distance = path_pos - last_path_pos
        if distance > 1 && !(qc == File::SEPARATOR || qc == '.')
          pc_prev = path_pos > 0 ? @path[path_pos - 1] : nil
          pc_score *= self.compute_factor(pc, pc_prev, distance)
        end
        if next_path_pos
          score_alt = score + self.compute_subscore(
            q, query_pos, next_path_pos, last_path_pos)
          best_score = score_alt if score_alt > best_score
        end
        score += pc_score
        last_path_pos = path_pos
        path_beg = path_pos + 1
      end
      score > best_score ? score : best_score
    end

    def find_next_matches(qc, path_beg)
      os = @offsets[qc]
      idx = (0...os.length).bsearch {|i| os[i] >= path_beg}
      idx.nil? ? [] : os[idx, 2]
    end

    def compute_factor(pc, pc_prev, distance)
      case
      when pc_prev == File::SEPARATOR
        0.9;
      when WORDBREAK_CHARS.include?(pc_prev)
        0.8;
      when LOWER.cover?(pc_prev) && UPPER.cover?(pc)
        0.8;
      when pc_prev == '.'
        0.7;
      else
        # if no "special" chars behind char, factor diminishes
        # as distance from last matched char increases
        (1.0 / distance) * 0.75;
      end
    end
  end
end
