use strict;
use v5.10;
use Test::More;
use Pandoc::Elements;

my $attr_hash = { classes => [qw(x x y)], answer => '42', id => '0' };

is_deeply attributes {}, [ '', [], [] ], 'empty attributes';
is_deeply attributes(undef), [ '', [], [] ], 'empty attributes (undef)';
is_deeply attributes $attr_hash, 
  [ '0', [qw(x x y)], [ [ answer => '42' ] ] ], 'classes and id';

done_testing;
