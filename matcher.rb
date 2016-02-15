require 'set'

class Matcher
  WORDBREAK_CHARS = Set['-', '_', ' '] + ('0'..'9')
  LOWER = ('a'..'z')
  UPPER = ('A'..'Z')

  class Query
    attr_reader :query, :query_len

    def initialize(query)
      @query = query
      @query_len = query.length
    end

    def score_path(path)
      PathMatch.new(path, self)
    end

  end

  class PathMatch
    attr_reader :path, :path_len, :max_score_per_char
    attr_accessor :score, :dot_file

    def initialize(path, q)
      @path = path
      @path_len = path.length()
      @max_score_per_char = (1.0 / @path_len + 1.0 / q.query_len) / 2.0
      @dot_file = false
      @subscores = Hash.new do |h, args|
        q = args.shift
        h[args] = self.send(:compute_subscore, q, *args)
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
      pc_prev = path_beg > 0 ? @path[path_beg - 1] : nil
      for query_pos in query_beg...q.query_len
        qc_match = false
        qc = q.query[query_pos]
        for path_pos in path_beg...@path_len
          pc = @path[path_pos]
          if qc.casecmp(pc) == 0
            qc_match = true
            pc_score = @max_score_per_char
            distance = path_pos - last_path_pos
            if distance > 1 && !(qc == File::SEPARATOR || qc == '.')
              pc_score *= self.compute_factor(pc, pc_prev, distance)
            end
            next_path_pos = path_pos + 1
            if @path_len - next_path_pos > q.query_len - query_pos
              score_alt = score +
                @subscores[[q, query_pos, next_path_pos, last_path_pos]]
              best_score = score_alt if score_alt > best_score
            end
            score += pc_score
            last_path_pos = path_pos
            pc_prev = pc
            break
          else
            pc_prev = pc
          end
        end
        return 0.0 if !qc_match
        path_beg = path_pos + 1
      end
      score > best_score ? score : best_score
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
