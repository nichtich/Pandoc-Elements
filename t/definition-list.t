use strict;
use warnings;

use Test::More 0.98; # subtests

use Pandoc::Elements;

my $doc = pandoc_json( '{"blocks":[{"c":[[[{"c":"placeat","t":"Str"}],[[{"c":[{"c":"Tempore","t":"Str"},{"t":"Space"},{"c":"Omnis","t":"Str"}],"t":"Para"}]]]],"t":"DefinitionList"}],"meta":{},"pandoc-api-version":[1,17,5,4]}' );
placeat

:   Tempore Omnis
DOC

note $doc->to_json;

$doc->walk( DefinitionList => sub { $_->content } );

unlike $doc->to_json, qr/\QPandoc::Document::DefinitionPair=ARRAY/, 'to_json';

done_testing;
