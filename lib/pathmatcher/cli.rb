require 'optparse'

module PathMatcher
  Options = Struct.new(:limit, :prefix_scores, :no_sort)

  class ParseError < Exception
  end

  class Help < Exception
  end

  module_function

  def base_options
    options = Options.new
    options.limit = nil
    options.prefix_scores = false
    options.no_sort = false
    options
  end

  def build_option_parser(run_opts)
    OptionParser.new do |opts|
      opts.banner =
        "usage: #{opts.program_name} [-l LIMIT] [-su] QUERY [FILE...]"

      opts.separator ''
      opts.separator 'options:'

      opts.on('-l', '--limit N', Integer,
              'Limit results to top N matches.') do |limit|
        run_opts.limit = limit
      end

      opts.on('-s', '--scores', 'Prefix matched paths with their scores.') do
        run_opts.prefix_scores = true
      end

      opts.on('-u', '--no-sort', 'Do not sort matched paths by score.') do
        run_opts.no_sort = true
      end

      opts.on('-h', '--help', 'Print this help.') do
        raise Help, opts
      end
    end
  end

  def invoke(args, input, output)
    begin
      run_opts = self.base_options
      op = self.build_option_parser(run_opts)
      op.parse!(args)
      if args.length < 1
        raise ParseError, "missing mandatory query argument\n#{op.banner}"
      end
      self.match_query(args.shift, run_opts, input, output)
    rescue OptionParser::ParseError => e
      raise ParseError, "#{e}\n#{op.banner}"
    end
  end

  def match_query(query_s, run_opts, input, output)
    q = Query.build(query_s)
    matches = []
    input.each_line do |path|
      pm = q.score_path(path.chomp)
      matches << pm if pm.score > 0.0
    end
    matches.sort_by! {|pm| [-pm.score, pm.path]} unless run_opts.no_sort
    matches = matches.take(run_opts.limit) if run_opts.limit
    matches.each do |pm|
      if run_opts.prefix_scores
        line = sprintf('%5d %s', (pm.score * 1e4).to_i, pm.path)
      else
        line = pm.path
      end
      output.puts line
    end
  end
end
