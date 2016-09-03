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

$e->keyvals( Hash::MultiValue->new(
    foo => 9, id => 0, bar => 8, foo => 7, class => 'a', class => 'b c',
) );
is_deeply $e->attr,
    [ '0', [qw(a b c)], [ [ foo => 9 ], [ bar => 8 ], [ foo => 7 ] ] ],
    'attributes via Hash::MultiValue';

$e->keyvals({ foo => 3, class => 'x y' });
is_deeply [ '0', [qw(a b c x y)], [ [ foo => 3 ] ] ], $e->attr, 'keyvals as setter';

$e->id(2);
is '2', $e->id, 'id setter';

$e->class('q r');
is_deeply [qw(q r)], $e->classes, 'classes setter';

$e->keyvals( a => 1, class => ['s'], a => 2 );
is_deeply [ '2', [qw(q r s)], [ [ a => 1 ], [ a => 2 ] ] ], $e->attr, 'keyvals as setter';


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
    ok $e->match(".$_"), 'class match';
}

ok !$e->match('.baz'), 'class selector';

done_testing;
