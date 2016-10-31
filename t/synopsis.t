use strict;
use Test::More;
use Pandoc::Elements;
use JSON;

my $ast = Document { 
        title => MetaInlines [ Str 'Greeting' ] 
    }, [
        Header( 1, attributes { id => 'de' }, [ Str 'Gruß' ] ),
        Para [ Str 'hello, world!' ],
    ], api_version_of => '1.18';

is_deeply $ast, { 
    'blocks' => [
        {   'c' => [ 1, [ 'de', [], [] ], [ { 'c' => 'Gruß', 't' => 'Str' } ] ],
            't' => 'Header'
        },
        { 'c' => [ { 'c' => 'hello, world!', 't' => 'Str' } ], 't' => 'Para' }
    ],
    'meta' => {
        'title' =>
          { 'c' => [ { 'c' => 'Greeting', 't' => 'Str' } ], 't' => 'MetaInlines' }
    },
    'pandoc-api-version' => [ 1, 17, 0, 4 ]
};

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
