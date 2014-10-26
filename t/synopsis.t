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

ok $ast->is_document, 'is_document';
ok !$ast->is_block, 'is_block';
ok !$ast->is_inline, 'is_inline';
ok !$ast->is_meta, 'is_meta';
ok !$ast->[1]->[0]->is_document, '!is_document';
ok $ast->[0]->{unMeta}{title}->is_meta, 'is_meta';
ok $ast->[1]->[0]->is_block, 'is_block';

my $json = JSON->new->utf8->convert_blessed->encode($ast);
is_deeply decode_json($json), $ast, 'encode/decode JSON';
$json = $ast->json;
is_deeply decode_json($json), $ast, 'encode/decode JSON (method json)';

done_testing;

__DATA__
% Greeting
# Gruß {.de}
hello, world!
