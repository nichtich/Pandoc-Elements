use strict;
use Test::More;
use Pandoc::Elements qw(attributes);

is_deeply attributes { }, ['',[],[]], 'empty attributes';
is_deeply attributes(undef), ['',[],[]], 'empty attributes (undef)';
is_deeply attributes { classes => [qw(x y)], answer => 42, id => 0 }, 
    ['0',[qw(x y)],[ answer => 42 ]], 'classes and id';

done_testing;
