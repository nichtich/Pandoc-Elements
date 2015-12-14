use strict;
use Test::More;
use Pandoc::Elements;

use_ok 'Pod::Simple::Pandoc';
my $parser = new_ok('Pod::Simple::Pandoc');

my $file = 'lib/Pod/Simple/Pandoc.pm';
# note explain $parser->_parser->parse_file($file)->root;

my $doc = $parser->parse_file($file);
isa_ok( $doc, 'Pandoc::Document', );

is_deeply $doc->query(
    Header => sub { $_[0]->level == 1 ? $_[0]->string : () } ),
  [ 'NAME', 'SYNOPSIS', 'DESCRIPTION', 'METHODS', 'MAPPING', 'LIMITATIONS', 'SEE ALSO' ],
  'got header';

$doc = $parser->parse_string(<<POD);
=over
 
I<hello>

=back
POD

is_deeply $doc, 
    Document({}, [ BlockQuote [ Para [ Emph [ Str 'hello' ] ] ] ]),
    'parse_string';

done_testing;
