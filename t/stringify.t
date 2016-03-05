use strict;
use Test::More;
use Pandoc::Elements;

my $ast = Document { }, [
    Header(1,attributes {},[ Str 'hello', Code attributes {}, ', ' ]),
    BulletList [ [ Plain [ Str 'world', Space, Str '!' ] ] ],
];

is $ast->string, 'hello, world !', 'stringify Document';

note $ast->string;

$ast->meta->{foo} = MetaInlines [ Emph [ Str "FOO" ] ];
$ast->meta->{bar} = MetaString "BAR";
$ast->meta->{doz} = MetaMap { x => MetaList [ MetaInlines [ Str "DOZ" ] ] };

is $ast->meta->{foo}->string, 'FOO', 'stringify MetaInlines';
is $ast->meta->{bar}->string, 'BAR', 'stringify MetaString';
is $ast->meta->{doz}->string, 'DOZ', 'stringify MetaMap>MetaList>MetaInlines';

note $ast->string;

is RawBlock('html','<b>hi</hi>')->string,  '', 'RawBlock has no string';
is RawInline('html','<b>hi</hi>')->string,  '', 'RawInline has no string';
is Code(attributes {},'#!$')->string,  '#!$', 'Code has string';

done_testing;

__DATA__
# hello`,`

* world !
