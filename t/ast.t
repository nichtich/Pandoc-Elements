use strict;
use Test::More;
use Pandoc::Elements;

my $doc = Document { title => MetaInlines [ Str 'test' ] },
            [ Para [ Str 'test' ] ];

ok $doc->is_document, 'is_document';
is $doc->name, 'Document', 'name';
is_deeply $doc->value, [ Para [ Str 'test' ] ];
ok !$doc->is_block, 'is_block';
ok !$doc->is_inline, 'is_inline';
ok !$doc->is_meta, 'is_meta';

my $meta = $doc->[0]->{unMeta};
is $meta, $doc->meta, '->meta';

ok $meta->{title}->is_meta, 'is_meta';
is $meta->{title}->name, 'MetaInlines', 'name';

my $para = $doc->[1]->[0];
is $para->name, 'Para', 'name';
is_deeply $para->value, [ Str 'test' ];
ok $para->is_block, 'is_block';
ok !$para->is_document, '!is_document';

done_testing;
