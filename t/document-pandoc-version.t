use strict;
use v5.10;
use Test::More;
use Test::Exception;
use Pandoc::Elements;

my @tests = (
    { pandoc_version => '1.18.1' } => [qw(1.17 1.18)],
    { api_version => 1.17 } => [qw(1.17 1.18)],
    { pandoc_version => '1.17' }  => [qw(1.16 1.16)],       # FIXME
    { pandoc_version => '1.16.0.2' } => [qw(1.16 1.16)],
    { pandoc_version => '1.15.1' } => [qw(1.12.3 1.12.1)],
    { pandoc_version => 1.9 } => undef,
    { pandoc_version => '1.0' } => undef,
);

while (@tests) {
    my ($args, $versions) = splice @tests, 0, 2;

    my $msg = join ' ', map { "$_ ".$args->{$_} } keys %$args;

    if ($versions) {
        my ($api, $pandoc) = @$versions;
        my $doc = Document {}, [], %$args;
        is $doc->api_version,  $api, "$msg => api $api";
        is $doc->pandoc_version,  $pandoc, "$msg => pandoc $pandoc";
    } else {
        throws_ok { Document {}, [], %$args }
            qr/pandoc version not supported/, "$msg => error";
    }
}

done_testing;
