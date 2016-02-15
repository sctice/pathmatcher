require 'set'

class Matcher
  WORDBREAK_CHARS = Set['-', '_', ' '] + ('0'..'9')

  class Query
    attr_reader :query

    def initialize(query)
      @query = query
      @query_len = query.length
    end

    def score_path(path)
      p = Path.new(path, @query_len)
      f = Frame.new
      best_score = 0.0
      stack = []
      loop do
        if f.path_pos >= p.path_len || f.query_pos >= @query_len
          f.score = 0.0 if f.query_pos < @query_len
          best_score = f.score if f.score > best_score
          break if stack.empty?
          f = stack.pop()
          next
        end
        qc = @query[f.query_pos]
        pc = p.path[f.path_pos]
        pc_prev = f.path_pos > 0 ? p.path[f.path_pos - 1] : nil
        qc_is_dot = qc == '.'
        p.dot_file = true if qc_is_dot && (
          f.path_pos == 0 || pc_prev == File::SEPARATOR)
        if qc.casecmp(pc) != 0
          # No match. Advance the path cursor once and keep looking.
          f.path_pos += 1
        else
          pc_score = p.max_score_per_char
          distance = f.path_pos - f.last_path_pos
          if distance > 1 && !(qc == File::SEPARATOR || qc == '.')
            factor = case
            when pc_prev == File::SEPARATOR
              0.9;
            when WORDBREAK_CHARS.include?(pc_prev)
              0.8;
            when pc_prev >= 'a' && pc_prev <= 'z' && pc >= 'A' && pc <= 'Z'
              0.8;
            when pc_prev == '.'
              0.7;
            else
              # if no "special" chars behind char, factor diminishes
              # as distance from last matched char increases
              (1.0 / distance) * 0.75;
            end
            pc_score *= factor;
          end
          f.path_pos += 1
          f_alt = f.clone
          f.score += pc_score
          f.last_path_pos = f.path_pos - 1
          f.query_pos += 1
          stack.push(f)
          f = f_alt
        end
      end
      p.score = best_score
      p
    end
  end

  class Path
    attr_reader :path, :path_len, :max_score_per_char
    attr_accessor :score, :dot_file

    def initialize(path, query_len)
      @path = path
      @path_len = path.length()
      @score = 0.0
      @max_score_per_char = (1.0 / @path_len + 1.0 / query_len) / 2.0
      @dot_file = false
    end
  end

  class Frame
    attr_accessor :score, :query_pos, :path_pos, :last_path_pos

    def initialize()
      @score = 0.0
      @query_pos = 0
      @path_pos = 0
      @last_path_pos = -1
    end
  end
end
