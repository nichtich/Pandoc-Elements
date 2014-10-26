use strict;
use Test::More;
use Pandoc::Elements qw(Emph Str attributes element);

is_deeply [ Emph 'hello' ], 
          [ { t => 'Emph', c => 'hello' } ], 'Emph';
is_deeply [ Emph 'hello', 'world' ], 
          [ { t => 'Emph', c => 'hello' }, 'world' ], 'Emph';
is_deeply [ Emph Str 'hello' ], 
          [ { t => 'Emph', c => { t => 'Str', c => 'hello' } } ], 'Emph';

is_deeply element( Code => attributes {}, 'x' ),
    { t => 'Code', c => [["",[],[]],"x"] }, 'element';

eval { element ( Foo => 'bar' ) }; ok $@, 'unknown element';
eval { element ( Code => 'x' ) }; ok $@, 'wrong number of arguments';

done_testing;
