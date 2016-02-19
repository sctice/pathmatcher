require 'mkmf'

abort "missing header ctype.h" unless have_header 'ctype.h'
abort "missing header strings.h" unless have_header 'strings.h'

abort "missing malloc()" unless have_func 'malloc'
abort "missing free()" unless have_func 'free'
abort "missing bzero()" unless have_func 'bzero'
abort "missing tolower()" unless have_func 'tolower'

create_makefile('pathmatchc')
