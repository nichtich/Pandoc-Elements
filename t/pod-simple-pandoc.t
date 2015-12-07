use strict;
use Test::More;
use Pandoc::Elements;

use_ok 'Pod::Simple::Pandoc';
my $parser = new_ok('Pod::Simple::Pandoc');

my $file = 't/example.pod';
# note explain $parser->_parser->parse_file($file)->root;

my $doc    = $parser->parse_file($file);
isa_ok($doc, 'Pandoc::Document',);

# note explain $doc;
# note $doc->to_json;

done_testing;
