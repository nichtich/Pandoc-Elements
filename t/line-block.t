use strict;
use Test::More;
use Pandoc::Elements;

Pandoc::Elements->can('LineBlock') or plan skip_all => 'Pandoc::Elements too old';

my $e = LineBlock [ [ Str "  foo"], [ Str "bar"], [ Str " baz"], ];

my $expected =bless(
    {   'c' => [
            [ bless( { 'c' => "  foo", 't' => 'Str' }, 'Pandoc::Document::Str' ) ],
            [ bless( { 'c' => "bar", 't' => 'Str' }, 'Pandoc::Document::Str' ) ],
            [ bless( { 'c' => " baz", 't' => 'Str' }, 'Pandoc::Document::Str' ) ]
        ],
        't' => 'LineBlock'
    },
    'Pandoc::Document::LineBlock'
);

is_deeply $e, $expected, 'object' or note explain $e;

my %expected = (
    '0' => {
        'c' => [
            { 'c' => "\x{a0}\x{a0}foo", 't' => 'Str' },
            { 'c' => [],                't' => 'LineBreak' },
            { 'c' => "bar",             't' => 'Str' },
            { 'c' => [],                't' => 'LineBreak' },
            { 'c' => "\x{a0}baz",       't' => 'Str' }
        ],
        't' => 'Para'
    },
    '1.18' => {
        'c' => [
            [ { 'c' => "\x{a0}\x{a0}foo", 't' => 'Str' } ],
            [ { 'c' => "bar",             't' => 'Str' } ],
            [ { 'c' => "\x{a0}baz",       't' => 'Str' } ]
        ],
        't' => 'LineBlock'
    },
);

my %api_versions = (
    undef          => { api_version => undef, expected => '1.18' },
    'empty string' => { api_version => "",    expected => '0' },
    '0'            => { api_version => '0',   expected => '0' },
    '1.12' => { api_version => pandoc_api_version_of( '1.12' ), expected => '0' },
    '1.18' => { api_version => pandoc_api_version_of( '1.18' ), expected => '1.18' },
);

for my $name ( sort keys %api_versions ) {
    local $Pandoc::Elements::PANDOC_API_VERSION = $api_versions{$name}{api_version};
    is_deeply $e->TO_JSON, $expected{ $api_versions{$name}{expected} }, "api-version: $name";
}

{

    # Pandoc::Document::TO_JSON() localizes $Pandoc::Elements::PANDOC_API_VERSION
    # according to the API version contained in the document, and then
    # Pandoc::Document::Element::TO_JSON() calls TO_JSON() recursively on
    # contained objects so that Pandoc::Document::LineBlock::TO_JSON()
    # picks up the right API version.

    local $Pandoc::Elements::PANDOC_API_VERSION = 0;

    my $doc = Document { 
        api_version_of => '1.18',
        meta => {},
        blocks => [
            Para [ Str 'foo' ],
            LineBlock [ [ Str 'baz' ], [ Str 'grault' ], [ Str 'corge' ] ],
            Para [ Str 'waldo' ],
        ],
    };

    is_deeply $doc->TO_JSON, 
    {   'blocks' => [
            { 'c' => [ { 'c' => 'foo', 't' => 'Str' } ], 't' => 'Para' },
            {   'c' => [
                    [ { 'c' => 'baz',    't' => 'Str' } ],
                    [ { 'c' => 'grault', 't' => 'Str' } ],
                    [ { 'c' => 'corge',  't' => 'Str' } ]
                ],
                't' => 'LineBlock'
            },
            { 'c' => [ { 'c' => 'waldo', 't' => 'Str' } ], 't' => 'Para' }
        ],
        'meta'               => {},
        'pandoc-api-version' => [ 1, 17, 0, 4 ]
    }, "doc's API version honored";

}

ok 1;

done_testing;
