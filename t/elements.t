use strict;
use Test::More;
use Pandoc::Elements qw(Emph Str attributes element);
use JSON;

is_deeply [ Str 'hello' ], 
          [ { t => 'Str', c => 'hello' } ], 'Emph';
is_deeply [ Str 'hello', 'world' ], 
          [ { t => 'Str', c => 'hello' }, 'world' ], 'Emph';
is_deeply [ Emph Str 'hello' ], 
          [ { t => 'Emph', c => { t => 'Str', c => 'hello' } } ], 'Emph';

is_deeply element( Code => attributes {}, 'x' ),
    { t => 'Code', c => [["",[],[]],"x"] }, 'element';

eval { element ( Foo => 'bar' ) }; ok $@, 'unknown element';
eval { element ( Code => 'x' ) }; ok $@, 'wrong number of arguments';

is_deeply decode_json(Str('今日は')->to_json), 
    { t => 'Str', c => '今日は' }, 'method to_json';

done_testing;
