use strict;
use Test::More;
use Pandoc::Walker;
use Pandoc::Elements qw(Str Space);

my $ast = load();

my $LINKS = [qw(
    http://example.org/
    image.png
    http://example.com/
)];

sub urls {
    my ($key, $value) = @_;
    return unless ($key eq 'Link' or $key eq 'Image');
    return $value->[1][0];
};

my $links = query $ast, \&urls;
is_deeply $links, $LINKS, 'query';

$links = [ ];
walk $ast, sub {
    my ($key, $value) = @_;
    return unless ($key eq 'Link' or $key eq 'Image');
    push @$links, $value->[1][0];
};

is_deeply $links, $LINKS, 'walk';

transform $ast, sub {
    my ($key, $value) = @_;
    return ($key eq 'Link' ? [] : ());
};

is_deeply query($ast,\&urls), ['image.png'], 'transform, remove elements';

$ast = load();
transform $ast, sub {
    my ($key, $value) = @_;
    return unless $key eq 'Link';
    return [ Str "<", @{$value->[0]}, Str ">" ];
};

my $header = $ast->[1][0]->{c}->[2];
is_deeply $header, [ 
    Str 'Example', Space, Str '<', Str 'http://example.org/', Str '>'
], 'transform, multiple elements';

done_testing;

sub load {
    use JSON;
    local (@ARGV, $/) = ('t/documents/example.json'); 
    decode_json(<>);
}
