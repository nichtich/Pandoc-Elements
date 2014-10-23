use strict;
use Test::More;
use Pandoc::Elements;

my $ast = Document { 
        title => MetaInlines [ Str 'Greeting' ] 
    }, [
        Header( 1, attributes { id => 'top' }, [ Str 'Hello' ] ),
        Para [ Str 'hello, world!' ],
    ];

is_deeply $ast, [ 
    { 
        unMeta => { 
            title => { 
                t => 'MetaInlines', 
                c => [{ t => 'Str', c => 'Greeting' }]
            }
        } 
    },
    [ 
        {
          t => 'Header', 
          c => [ 1, ['top',[],[]], [ { t => 'Str', c => 'Hello' } ] ]
        },
        { t => 'Para', c => [ { t => 'Str', c => 'hello, world!' } ] } 
    ]
];

done_testing;

__DATA__
% Greeting
# Hello {.top}
Hello, world!
