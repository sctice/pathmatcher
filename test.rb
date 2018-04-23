#!/usr/bin/env ruby

require_relative 'build'

TEST_SUITE = File.join('test', 'suite.rb')

def run_tests!
  build_ext!
  load TEST_SUITE
end

run_tests! if __FILE__ == $PROGRAM_NAME
