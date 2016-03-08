use strict;
use Test::More;
use Pandoc::Elements qw(attributes Code Document Para);

my $attr_hash = { classes => [qw(x y)], answer => '42', id => '0' };
my $element = Code attributes $attr_hash, "x";

is_deeply attributes { }, ['',[],[]], 'empty attributes';
is_deeply attributes(undef), ['',[],[]], 'empty attributes (undef)';
is_deeply attributes $attr_hash, ['0',[qw(x y)],[ [ answer => '42' ] ]], 'classes and id';
is_deeply { $element->attr_list }, $attr_hash, 'attributes--hashified attr_list equivalence';

SKIP: {
    eval { require Hash::MultiValue } or skip 'Hash::MultiValue not installed', 1;

    my $hmv = Hash::MultiValue->from_mixed( $element->attr_list );

    is_deeply $hmv->as_hashref_mixed, $attr_hash, 'to Hash::MultiValue and back';
}

SKIP: {
    eval { require IPC::Run3 } or skip 'IPC::Run3 not installed', 2;

    my $document = Document {}, [Para [Code attributes { classes => [qw(x y)], answer => '42', id => '0' }, "x"]];
    my $json = $document->to_json;

    IPC::Run3::run3( [pandoc => -f => 'json', -t => 'markdown'], \$json, \my $stdout, \my $stderr );

    unlike $stderr, qr/\Qwhen expecting a [a], encountered Object instead/, 'pandoc reads attrs ok';
    like $stdout, qr/\Q{#0 .x .y answer="42"}/, 'attrs converted ok';
}

done_testing;
