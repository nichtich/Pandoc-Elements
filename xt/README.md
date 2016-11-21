This directory contains tests to run with multiple versions of pandoc
executable. 

Script `get-pandoc-releases.pl` downloads all available binary releases of
pandoc (limited to Debian 64bit) and stores them in subdirectory `bin`.

Run all normal tests with a selected binary by setting `PATH`:

    PATH=xt/bin/1.15.2:$PATH prove -l

