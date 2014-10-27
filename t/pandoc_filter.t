use Test::More;
use Pandoc::Filter;
use Pandoc::Elements;
use JSON;
use Encode;

my $ast = Pandoc::Elements::from_json('{"t":"Str","c":"☃"}');
is_deeply $ast, { t => 'Str', c => decode_utf8("☃") }, 'JSON with Unicode';
Pandoc::Filter->new()->apply($ast);
is_deeply $ast, { t => 'Str', c => decode_utf8("☃") }, 'identity filter';

sub shout {
    return unless $_[0]->name eq 'Str';
    return Str($_[0]->content.'!');
}

# FIXME: cannot directly filter root element
$ast = [$ast];
Pandoc::Filter->new(\&shout)->apply($ast);
is_deeply $ast, [{ t => 'Str', c => "\x{2603}!" }], 'applied filter';

{
    use Test::Output;
    local *STDIN = *DATA;
    stdout_like(sub { 
            pandoc_filter( \&shout ) 
        }, qr/"c":"☃!"/), 'pandoc_filter';
}

done_testing;

__DATA__
[{"unMeta":{}},[{"t":"Para","c":[{"t":"Str","c":"☃"}]}]]
