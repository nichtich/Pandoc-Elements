use strict;
use Test::More;
use Pandoc::Elements;

is_deeply [ Emph 'hello' ], 
          [ { t => 'Emph', c => 'hello' } ];
is_deeply [ Emph 'hello', 'world' ], 
          [ { t => 'Emph', c => 'hello' }, 'world' ];
is_deeply [ Emph Emph 'hello' ], 
          [ { t => 'Emph', c => { t => 'Emph', c => 'hello' } } ];

done_testing;
