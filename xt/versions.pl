use strict;
use Test::More;
use Pandoc;

my @releases = glob 'xt/bin/*/pandoc';

my $PATH = $ENV{PATH};

foreach my $bin (@releases) {
    my $pandoc = Pandoc->new( $bin );

    my $version = $bin; $version =~ s/[^0-9.]//g;
    is $pandoc->version, $version, $version;

    my $doc = $pandoc->parse( markdown => "| line\n" );
    say $doc->api_version;
    say $doc->to_json;

    local $ENV{PATH} = "xt/bin/$version:$PATH";
    local $ENV{RELEASE_TESTING} = 1;
    system 'prove -l';
}

done_testing;
