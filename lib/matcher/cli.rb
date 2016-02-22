require 'optparse'

module Matcher
  Options = Struct.new(:limit, :prefix_scores, :no_sort)

  module_function

  def base_options
    options = Options.new
    options.prefix_scores = false
    options.no_sort = false
    options
  end

  def build_option_parser(run_opts)
    OptionParser.new do |opts|
      opts.banner = 'Usage: fuzmatch [-l LIMIT] [-su] QUERY [FILE...]'

      opts.separator ''
      opts.separator 'Options:'

      opts.on('-l', '--limit N', Integer,
              'Limit results to top N matches') do |limit|
        run_opts.limit = limit
      end

      opts.on('-s', '--scores', 'Prefix matched paths with their scores') do
        run_opts.prefix_scores = true
      end

      opts.on('-u', '--no-sort', 'Do not sort matched paths by score') do
        run_opts.no_sort = true
      end

      opts.on('-h', '--help', 'Print this help') do
        puts opts
        exit
      end
    end
  end

  def invoke(args, argf)
    begin
      run_opts = self.base_options
      op = self.build_option_parser(run_opts)
      op.parse!(args)
      if args.length < 1
        puts "Missing mandatory query argument.", "", op.banner
        exit
      end
      self.match_query(args.shift, run_opts, argf)
    rescue OptionParser::InvalidOption => e
      op.warn(e)
      puts "", op.banner
    end
  end

  def match_query(query_in, run_opts, argf)
    q = Matcher::Query.build(query_in)
    matches = []
    argf.each_line do |path|
      pm = q.score_path(path)
      matches << pm if pm.score > 0.0
    end
    matches.sort_by! {|pm| -pm.score} if !run_opts.no_sort
    matches.take(run_opts.limit || matches.size).each do |pm|
      if run_opts.prefix_scores
        line = sprintf('%5d %s', (pm.score * 1e4).to_i, pm.path)
      else
        line = pm.path
      end
      puts line
    end
  end
end
