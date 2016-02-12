use strict;
use Test::More;
use Pandoc::Elements;
use JSON;

my $oldjson = do { 
    local (@ARGV, $/) = ('t/documents/link-image-oldstyle.json'); 
    <>;
};
my $newjson = do {
    local (@ARGV, $/) = ('t/documents/link-image-attributes.json'); 
    <>;
};

my $olddoc = pandoc_json($oldjson);
my $newdoc = pandoc_json($newjson);

is_deeply $olddoc, $newdoc, 'parse old and new (Pandoc >= 1.16) format';

is_deeply decode_json($newjson), decode_json($newdoc->to_json), 'encode new format';

$Pandoc::Elements::LinkImageAttributes = 0;
is_deeply decode_json($oldjson), decode_json($newdoc->to_json), 'encode old format';

done_testing;
