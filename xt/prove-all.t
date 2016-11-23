use strict;
use Test::More;
use File::Basename;

use lib 'xt/lib';
use Pandoc::Releases;

my $PATH = $ENV{PATH};

foreach my $pandoc (pandoc_releases) {
    note $pandoc->bin;
    local $ENV{PATH} = dirname($pandoc->bin).":$PATH";
    local $ENV{RELEASE_TESTING} = 1;
    system 'prove -l';
}

done_testing;
