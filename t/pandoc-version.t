use strict;
use Test::More;
use Test::Exception;

local $ENV{PANDOC_VERSION} = '1.2.3';
require Pandoc::Elements;
is Pandoc::Elements::pandoc_version(), '1.2.3', 'pandoc_version from ENV';

Pandoc::Elements->import('pandoc_version');

$Pandoc::Elements::PANDOC_VERSION = 1.3;
is pandoc_version(), '1.3', 'set pandoc_version via variable';

{
    local $Pandoc::Elements::PANDOC_VERSION = undef;
    is pandoc_version(), '1.18', 'maximum supported version';
}
is pandoc_version(), '1.3', 'localize PANDOC_VERSION';

my @versions = (
    '1.12.2'    => undef,
    '1.12.3'    => '1.12.1',
    '1.12.4'    => '1.12.1',
    '1.16'      => '1.16',
    '1.16.1'    => '1.16',
    '1.17'      => '1.18',
    '1.17.0.4'  => '1.18',
    '1.99'      => undef,
);

while ( my ($api,$pandoc) = splice @versions, 0, 2 ) {
    is pandoc_version( api => $api ), $pandoc, 
        defined $pandoc
            ? "pandoc-api-version $api requires pandoc $pandoc"
            : "pandoc-api-version $api not supported";
}

done_testing;
