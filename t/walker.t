use strict;
use Test::More;
use Pandoc::Walker;
use Pandoc::Elements qw(Str Space from_json);

sub load {
    local (@ARGV, $/) = ('t/documents/example.json'); 
    from_json(<>);
}

my $doc = load();

my $LINKS = [qw(
    http://example.org/
    image.png
    http://example.com/
)];

sub urls {
    my ($name, $value) = ($_[0]->name, $_[0]->value);
    return unless ($name eq 'Link' or $name eq 'Image');
    return $value->[1][0];
};

my $links = query $doc, \&urls;
is_deeply $links, $LINKS, 'query';

$links = [ ];
walk $doc, sub {
    my ($name, $value) = ($_[0]->name, $_[0]->value);
    return unless ($name eq 'Link' or $name eq 'Image');
    push @$links, $value->[1][0];
};

is_deeply $links, $LINKS, 'walk';

transform $doc, sub {
    return ($_[0]->name eq 'Link' ? [] : ());
};

is_deeply query($doc,\&urls), ['image.png'], 'transform, remove elements';

$doc = load();
transform $doc, sub {
    my ($e) = @_;
    return unless $e->name eq 'Link';
    my $a = [ Str "<", @{$e->value->[0]}, Str ">" ];
    return $a;
};

my $header = $doc->value->[0]->value->[2];
is_deeply $header, [ 
    Str 'Example', Space, Str '<', Str 'http://example.org/', Str '>'
], 'transform, multiple elements';

done_testing;
