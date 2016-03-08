use strict;
use Test::More;
use Pandoc::Elements qw(attributes Code Document Para);


SKIP: {
    exists $ENV{PANDOC_VERSION} or skip 'pandoc seems to be missing', 2;
    eval { require IPC::Run3 } or skip 'IPC::Run3 not installed', 2;

    my $document = Document {}, [Para [Code attributes { classes => [qw(x y)], answer => '42', id => '0' }, "x"]];
    my $json = $document->to_json;

    IPC::Run3::run3( [pandoc => -f => 'json', -t => 'markdown'], \$json, \my $stdout, \my $stderr );

    unlike $stderr, qr/\Qwhen expecting a [a], encountered Object instead/, 'pandoc reads attrs ok';
    like $stdout, qr/\Q{#0 .x .y answer="42"}/, 'attrs converted ok';
}

done_testing;
