#!/usr/bin/env ruby

require 'fileutils'

EXT_NAME = 'pathmatchc'
EXT_DIR = File.join('ext', EXT_NAME)
LIB_DIR = File.join('lib', EXT_NAME)
OBJ_GLOB = File.join(EXT_DIR, '*.{o,so,bundle,dll,dylib}')

def build_ext!
  built = false
  Dir.chdir(EXT_DIR) do
    load 'extconf.rb' if FileUtils.uptodate?('extconf.rb', ['Makefile'])
    abort "make returned a failure exit status" unless system('make')
  end
  object_files = Dir[OBJ_GLOB]
  object_files.each do |f|
    target_f = File.join(LIB_DIR, File.basename(f))
    if !FileUtils.uptodate?(target_f, [f])
      puts "copying #{f} to #{LIB_DIR}"
      FileUtils.cp f, LIB_DIR
    end
  end
end

build_ext! if __FILE__ == $PROGRAM_NAME
