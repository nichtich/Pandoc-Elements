use strict;
use Test::More;
use Pandoc::Filter;
use Pandoc::Elements;

my $action = sub {
    my ($e, $f, $m) = @_;

    return unless $e->name eq 'Header' and $e->level >= 2;

    if ($f) {
        Para [ Str $f . ':' . $m->{title}->string ]
    } else {
        Para [ Emph $e->content ];
    }
};
my $h1 = Header(1, attributes {}, [ Str 'hello']);
my $h2 = Header(2, attributes {}, [ Str 'hello']);

is $action->($h1), undef, 'action';
is_deeply $action->($h2), Para [ Emph [ Str 'hello' ] ], 'action';

{
    my $doc = Document {}, [ $h1, $h2 ];
    Pandoc::Filter->new($action)->apply($doc);
    is_deeply $doc->content->[1], Para [ Emph [ Str 'hello' ] ], 'apply';
}

{
    my $doc = Document { title => MetaInlines [ Str 'test' ] }, [ $h1, $h2 ];
    Pandoc::Filter->new($action)->apply($doc, 'html');
    is_deeply $doc->content->[1], Para [ Str 'html:test' ], 'format and metadata';
}

eval { Pandoc::Filter->new( 1 ) }; ok $@, 'invalid filter';

my $doc = Document {}, [ Str "hello" ];
Pandoc::Filter->new(sub {
    return if $_->name ne 'Str';
    $_->{c} = uc $_->{c};
    return [ $_, Str " world!" ];
})->apply($doc);

is_deeply $doc->content, [ Str('HELLO'), Str(' world!') ], "don't filter injected elements";

done_testing;
