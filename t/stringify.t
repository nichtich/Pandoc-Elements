use strict;
use Test::More;
use Pandoc::Elements;

my $ast = Document { }, [
    Header(1,attributes {},[ Str 'hello', Code attributes {}, ', ' ]),
    BulletList [ [ Plain [ Str 'world', Space, Str '!' ] ] ],
];

is $ast->string, 'hello, world !';

is RawBlock('html','<b>hi</hi>')->string,  '', 'RawBlock has no string';
is RawInline('html','<b>hi</hi>')->string,  '', 'RawInline has no string';
is Code(attributes {},'#!$')->string,  '#!$', 'Code has string';

done_testing;

__DATA__
# hello`,`

* world !
