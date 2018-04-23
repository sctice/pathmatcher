# Matcher

This is a standalone library that does the same fuzzy-find matching as
Command-T.vim. It is a fork of [__@burke's__ project][1] that implements the
algorithm in C. This project implements the algorithm in both Ruby and C (as a
Ruby extension), using Ruby for everything but the core matching algorithm.
There is also a pure Ruby implementation of the algorithm that will be
automatically used in environemts where the C extension cannot be build.

[1]: https://github.com/burke/matcher

# Installation

```shell
$ ./build.rb
```

Once the extension is built (or not, if you cannot build it in your
environment), create a symbolic link to `bin/pmatch`.

# Usage

The `pmatch` command searches for a string in a list of filenames and returns
the ones it thinks you are most likely referring to. It works exactly like
fuzzy-finder, Command-T, and so on.

### Usage:

```shell
$ pmatch [options] <search>
```

#### Options:

* `--limit`: The number of matches to return (default no limit).
* `--scores`: Display the score in front of each match, separated by a space.
* `--no-sort`: Don't sort the matches (perhaps useful if you wanted to offload
  sorting to the `sort` utility using the `--scores` option).

### Examples

```shell
$ pmatch --limit 5 customer.rb filelist.txt
$ find . | pmatch order
```

# Using with CtrlP.vim

```viml
let g:path_to_pmatch = "/path/to/pmatch"

let g:ctrlp_user_command = ['.git/', 'cd %s && git ls-files . -co --exclude-standard']

let g:ctrlp_match_func = { 'match': 'GoodMatch' }

function! GoodMatch(items, str, limit, mmode, ispath, crfile, regex)
  " a:mmode is currently ignored. In the future, we should probably do
  " something about that. pmatch behaves like "full-line".
  let cmd = 'pmatch --limit ' . a:limit . ' ' . a:str
  return split(system(cmd, join(a:items, "\n")."\n"))
endfunction
```

# Bugs

Probably

# Contributing

Fork branch commit push pullrequest
