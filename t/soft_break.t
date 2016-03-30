use strict;
use Test::More;
use Pandoc::Elements qw(pandoc_json Space);

my $json_in = <DATA>;
my $ast = pandoc_json( $json_in );

SKIP: {
    eval { require Clone::PP } or skip 'Clone::PP not installed', 2;

    my $modified = Clone::PP::clone($ast)->transform( SoftBreak => sub { Space } );

    unlike $modified->to_json, qr/"SoftBreak"/, 'no SoftBreak in cloned ast';
    like $ast->to_json, qr/"SoftBreak"/, 'preserved SoftBreak in original ast';
}

$ast->transform( SoftBreak => sub { Space } );

is $ast->string,
    'Dolorem sapiente ducimus quia beatae sapiente perspiciatis quia. Praesentium est cupiditate architecto temporibus eos.',
    'replaced SoftBreak with spaces';

unlike $ast->to_json, qr/"SoftBreak"/, 'no SoftBreak in modified ast';

done_testing;

__DATA__
[{"unMeta":{}},[{"t":"Para","c":[{"t":"Str","c":"Dolorem"},{"t":"Space","c":[]},{"t":"Str","c":"sapiente"},{"t":"Space","c":[]},{"t":"Str","c":"ducimus"},{"t":"Space","c":[]},{"t":"Str","c":"quia"},{"t":"SoftBreak","c":[]},{"t":"Str","c":"beatae"},{"t":"Space","c":[]},{"t":"Str","c":"sapiente"},{"t":"Space","c":[]},{"t":"Str","c":"perspiciatis"},{"t":"Space","c":[]},{"t":"Str","c":"quia."},{"t":"SoftBreak","c":[]},{"t":"Str","c":"Praesentium"},{"t":"Space","c":[]},{"t":"Str","c":"est"},{"t":"Space","c":[]},{"t":"Str","c":"cupiditate"},{"t":"SoftBreak","c":[]},{"t":"Str","c":"architecto"},{"t":"Space","c":[]},{"t":"Str","c":"temporibus"},{"t":"Space","c":[]},{"t":"Str","c":"eos."}]}]]

