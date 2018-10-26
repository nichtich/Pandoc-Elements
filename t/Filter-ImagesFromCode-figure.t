use strict;
use warnings;

use Test::More 0.98; # subtests
use Pandoc::Elements;
use Pandoc;
use Pandoc::Filter::ImagesFromCode;
use File::Temp 'tempdir';

if ( pandoc->version < 1.16 ) {
    plan skip_all => 'pandoc executable is too old for these tests (< 1.16)';
}

my $dir = tempdir( CLEANUP => 1 );

my $perlcode = 'print "Totally ignored! :-)";';

my %for_attr = (
    id      => 'x',
    title   => 'a title',
    class   => 'perl',
    caption => 'a caption',
    fig     => 1,
);

my %for_filter = (
    dir     => $dir,
    from    => 'pl',
    to      => 'txt',
    capture => 1,
    run     => [ 'perl', '$infile$' ],
);

my @fig_tests = (
    {   name   => 'figure',
        attr   => {%for_attr},
        filter => {%for_filter},
        json   => [
            [ qr/"t":"Para"/,  'wrapped in Para' ],
            [ qr/fig:a title/, 'fig: prefix' ],
        ],
        html => [
            [ qr{<figure>.*</figure>}s,               'figure' ],
            [ qr{<figcaption>a caption</figcaption>}, 'figcaption' ],
        ]
    },
    {   name => 'fig-caption',
        attr => {
            %for_attr,
            'fig-caption' => "This is a &quot;real&quot;, *styled* caption",
        },
        filter => {%for_filter},
        json   => [],
        html   => [
            [   qr{<figcaption>This is a “real”, <em>styled</em> caption</figcaption>},
                'figcaption'
            ],
        ],
    },
    {   name => 'pandoc',
        attr =>
          { %for_attr, 'fig-caption' => "This is a &quot;real&quot; caption", },
        filter => { %for_filter, pandoc => [ 'pandoc', '--standalone' ] },
        json   => [],
        html   => [
            [   qr{<figcaption>This is a “real” caption</figcaption>},
                'figcaption'
            ],
        ],
    },
    {   name => 'no smart',
        attr =>
          { %for_attr, 'fig-caption' => "This is a &quot;real&quot; caption", },
        filter => { %for_filter, reader_exts => '-smart' },
        json   => [ [ qr{"c":"\\"real\\"","t":"Str"}, 'dumb quotes in JSON' ] ],
        html =>
          [ [ qr{This is a &quot;real&quot; caption}, 'dumb quotes in HTML' ], ],
    },
    {   name => 'smart anyway',
        attr => {
            %for_attr,
            'reader-ext'  => '+smart',
            'fig-caption' => "This is a &quot;real&quot; caption",
        },
        filter => { %for_filter, reader_exts => '-smart' },
        json   => [ [ qr/"t":"DoubleQuote"/, 'DoubleQuote' ] ],
        html   => [ [ qr{This is a “real” caption}, 'smart quotes' ], ],
    },
);

for my $test ( @fig_tests ) {
    subtest $test->{name} => sub {
        my $doc = Document {}, [ CodeBlock attributes $test->{attr}, $perlcode ];

        my $filter = Pandoc::Filter::ImagesFromCode->new( %{$test->{filter}});

        $filter->apply($doc);

        my $json = $doc->to_json;

        # note $json;

        for my $json_test ( @{$test->{json}} ) {
            &like( $json, @$json_test ); # bypass prototype
        }

        my $html = $doc->to_pandoc( -t => 'html5' );

        # note $html;

        for my $html_test ( @{$test->{html}} ) {
            &like( $html, @$html_test ); # bypass prototype
        }

    };
}

done_testing;
