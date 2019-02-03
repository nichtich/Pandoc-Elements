use strict;
use warnings;

use Test::More 0.98; # subtests

use Pandoc::Elements;
use Pandoc;

my $doc = pandoc->parse( markdown => <<'DOC' );
placeat

:   Tempore Omnis
DOC

$doc->walk( DefinitionList => sub { $_->content } );

unlike $doc->to_json, qr/\QPandoc::Document::DefinitionPair=ARRAY/, 'to_json';

done_testing;
