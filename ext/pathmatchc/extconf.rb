require 'mkmf'

abort "missing header ctype.h" unless have_header 'ctype.h'
abort "missing header string.h" unless have_header 'string.h'

abort "missing malloc()" unless have_func 'malloc'
abort "missing free()" unless have_func 'free'
abort "missing memset()" unless have_func 'memset'
abort "missing tolower()" unless have_func 'tolower'

create_makefile('pathmatchc')
