use strict;
use Test::More;
use Pandoc::Elements;
use Pandoc;
use Pod::Simple::Pandoc;

my $file = 'lib/Pod/Simple/Pandoc.pm';

sub headers {
    $_[0]->query( Header => sub { $_->level == 1 ? $_->string : () } )
}

my $parser = new_ok 'Pod::Simple::Pandoc';

# parse_file
{
    my $doc = $parser->parse_file($file);
    isa_ok $doc, 'Pandoc::Document';

    is_deeply 
        $doc->query( Header => sub { $_->level == 1 ? $_->string : () } ),
        [qw(NAME SYNOPSIS DESCRIPTION OPTIONS METHODS MAPPING ),'SEE ALSO'],
        'got headers';
}

# parse_string
{
    my $doc = $parser->parse_string(<<POD);
=over
 
I<hello>

=back
POD

    is_deeply $doc, 
        Document({}, [ BlockQuote [ Para [ Emph [ Str 'hello' ] ] ] ]),
        'parse_string';
}

# podurl
{
    my %opt = (podurl => 'http://example.org/');
    my $doc = Pod::Simple::Pandoc->new(%opt)->parse_file($file);
    my $urls = $doc->query( Link => sub { $_->url } );
    is $urls->[0], 'http://example.org/perlpod', 'podurl';
}

# data-sections
if (pandoc and pandoc->version('1.12')) {
    my %opt = ('data-sections' => 1);
    my $doc = Pod::Simple::Pandoc->new(%opt)->parse_file($file);
    is_deeply
        $doc->query( Header => sub { $_->level == 3 ? $_->string : () } ),
        ['Examples'],
        'data-sections';
}

done_testing;
