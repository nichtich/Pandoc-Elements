use strict;
use Test::More;
use Pandoc::Elements;
use JSON;

my $ast = Document { 
        title => MetaInlines [ Str 'Greeting' ] 
    }, [
        Header( 1, attributes { id => 'de' }, [ Str 'Gruß' ] ),
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
          c => [ 1, ['de',[],[]], [ { t => 'Str', c => 'Gruß' } ] ]
        },
        { t => 'Para', c => [ { t => 'Str', c => 'hello, world!' } ] } 
    ]
];

my $json = JSON->new->utf8->convert_blessed->encode($ast);
is_deeply decode_json($json), $ast, 'encode/decode JSON';
is_deeply Pandoc::Elements::pandoc_json($json), $ast, 'pandoc_json';
$json = $ast->to_json;
is_deeply decode_json($json), $ast, 'to_json';

eval { Pandoc::Elements->pandoc_json(".") };
like $@, qr{.+at.+synopsis\.t}, 'error in pandoc_json';

done_testing;

__DATA__
% Greeting
# Gruß {.de}
hello, world!
