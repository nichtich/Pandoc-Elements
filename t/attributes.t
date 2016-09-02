use strict;
use v5.10;
use Test::More;
use Pandoc::Elements;
use Hash::MultiValue;

my $attr_hash = { class => [qw(x x y)], answer => 42, id => 0 };

is_deeply attributes {}, [ '', [], [] ], 'empty attributes';
is_deeply attributes(undef), [ '', [], [] ], 'empty attributes (undef)';
is_deeply attributes $attr_hash,
  [ '0', [qw(x x y)], [ [ answer => '42' ] ] ], 'classes and id';

my $e = Code attributes $attr_hash, '';
is_deeply [ $e->keyvals->flatten ], [ answer => '42' ], 'keyvals';

$e = Code [ '', [], [ [ foo => '1' ], [ bar => '2' ], [ foo => '3' ] ] ], '';
is_deeply [ $e->keyvals->flatten ], [ foo => 1, bar => 2, foo => 3 ], 'keyvals';

my $a = Hash::MultiValue->new(
    foo => 1, id => 0, bar => 2, foo => 3, class => 'a', class => 'b c',
);
$e = Code attributes $a, 'x';
is_deeply $e->attr,
    [ '0', [qw(a b c)], [ [ foo => 1 ], [ bar => 2 ], [ foo => 3 ] ] ],
    'attributes via Hash::MultiValue';

my @class_hashes = (
    { class => [qw(foo bar doz)] },
    { class => 'foo bar doz ' },
    { class => " foo\t bar\n  doz " },
);

foreach (@class_hashes) {
    $e = CodeBlock attributes $_, '';
    is_deeply $e->classes, [qw(foo bar doz)], 'class(es) attributes';
}

foreach (qw(foo bar doz)) {
    is $e->class($_), $_, 'class selector';
}

is $e->class('baz'), '', 'class selector';

done_testing;
