This directory contains tests to run with multiple versions of pandoc
executable. 

Script `get-pandoc-releases.pl` downloads all available binary releases of
pandoc (limited to Debian 64bit) and stores them in subdirectory `bin`:

    $ perl -Ilib xt/get-pandoc-releases.pl

Run all normal tests (or a selected test) by selecting a binary with `PATH`:

    $ PATH=xt/bin/1.15.2:$PATH prove -l

Run all normal tests with all pandoc releases:

    $ perl -Ilib xt/prove-all.t
