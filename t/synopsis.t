use strict;
use Test::More;

use Pandoc::Elements;
use JSON;

# TODO: use Test::Deep::noclass() instead? See synopsis-noclass.t!
#
# HACK: De-objectify api-version so that tests pass.
# This is a bug in Test::More::is_deeply(), not in Pandoc::Elements:
# is_deeply() compares the stringification of overloaded objects,
# even though it's supposed to compare data structures!
# Test::Deep offers a non-broken way of doing this and more.
    
my $doc = Document { 
        title => MetaInlines [ Str 'Greeting' ] 
    }, [
        Header( 1, attributes { id => 'de' }, [ Str 'Gruß' ] ),
        Para [ Str 'hello, world!' ],
    ],
    api_version_of => '1.18';

#<<<
is_deeply $doc,
  bless(
    { 'blocks' => [
        bless(
          { 'c' => [
              1,
              [ 'de', [], [] ],
              [ bless( { 'c' => 'Gruß', 't' => 'Str' }, 'Pandoc::Document::Str' ) ]
            ],
            't' => 'Header'
          },
          'Pandoc::Document::Header'
        ),
        bless(
          { 'c' => [
              bless( { 'c' => 'hello, world!', 't' => 'Str' }, 'Pandoc::Document::Str' )
            ],
            't' => 'Para'
          },
          'Pandoc::Document::Para'
        )
      ],
      'meta' => {
        'title' => bless(
          { 'c' =>
              [ bless( { 'c' => 'Greeting', 't' => 'Str' }, 'Pandoc::Document::Str' ) ],
            't' => 'MetaInlines'
          },
          'Pandoc::Document::MetaInlines'
        )
      },
      'pandoc-api-version' => bless( [ 1, 17, 0, 4 ], 'Pandoc::Document::ApiVersion' )
    },
    'Pandoc::Document'
    ),
  'document';
#>>>

my $ast = $doc->TO_JSON;

is_deeply $ast,
  { 'blocks' => [
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
  }, 'ast';

my $json = JSON->new->utf8->convert_blessed->encode($doc);
is_deeply decode_json($json), $ast, 'encode/decode JSON';
is_deeply Pandoc::Elements::pandoc_json($json), $doc, 'pandoc_json';
$json = $doc->to_json;
is_deeply decode_json($json), $ast, 'to_json';

eval { Pandoc::Elements->pandoc_json(".") };
like $@, qr{.+at.+synopsis\.t}, 'error in pandoc_json';

done_testing;

__DATA__
% Greeting
# Gruß {.de}
hello, world!
