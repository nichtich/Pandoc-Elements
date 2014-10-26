use strict;
use Test::More;
use Pandoc::Filter;
use Pandoc::Elements;

my $ast = Document { }, [
    Header(1,attributes {},[ Str 'hello', Code attributes {}, ', ' ]),
    BulletList [ [ Plain [ Str 'world', Space, Str '!' ] ] ],
];

is stringify($ast), 'hello, world !';

done_testing;

__DATA__
# hello`,`

* world !
