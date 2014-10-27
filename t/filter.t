use strict;
use Test::More;
use Pandoc::Filter;
use Pandoc::Elements;

my $action = sub {
    return unless ($_[0]->name eq 'Header' and $_[0]->level >= 2);
    return Para [ Emph $_[0]->content ];
};
my $h1 = Header(1, attributes {}, [ Str 'hello']);
my $h2 = Header(2, attributes {}, [ Str 'hello']);

is $action->($h1), undef, 'action';
is_deeply $action->($h2), Para [ Emph [ Str 'hello' ] ], 'action';

my $doc = Document {}, [ $h1, $h2 ];
Pandoc::Filter->new($action)->apply($doc);

is_deeply $doc->content->[1], Para [ Emph [ Str 'hello' ] ], 'apply';

eval { Pandoc::Filter->new( 1 ) }; ok $@, 'invalid filter';

done_testing;
