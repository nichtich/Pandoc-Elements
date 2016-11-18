use strict;
use Test::More 0.96; # subtests
use Test::Exception;
use Pandoc::Elements;
use JSON qw( decode_json );

use utf8;

sub list2content {
    my @content = map { Str( $_ ), Space } @_;
    pop @content;    # remove trailing space
    return \@content;
}

my %data = (
    old_style => [
        [   'actual old-style' => [
                { title => MetaInlines( [Plain list2content qw[A message] ] ) },
                [   Header( 1, attributes {}, list2content qw[Hej Världen!] ),
                    Para list2content qw[Hur mår du idag?]
                ],
            ],
        ],

        [   'old-style with 0 api-version' => [
                { title => MetaInlines( [Plain list2content qw[A message] ] ) },
                [   Header( 1, attributes {}, list2content qw[Hej Världen!] ),
                    Para list2content qw[Hur mår du idag?]
                ],
                api_version => 0
            ],
        ],

        [   'old-style AST' => [
                [   {   unMeta => {
                            title => MetaInlines( [Plain list2content qw[A message] ] )
                        }
                    },
                    [   Header( 1, attributes {}, list2content qw[Hej Världen!] ),
                        Para list2content qw[Hur mår du idag?]
                    ]
                ]
            ],
        ],

        [   'new-style AST without api version' => [
                {   meta =>
                      { title => MetaInlines( [Plain list2content qw[A message] ] ) },
                    blocks => [
                        Header( 1, attributes {}, list2content qw[Hej Världen!] ),
                        Para list2content qw[Hur mår du idag?]
                    ],
                }
            ],
        ],

        [   'new-style AST with 0 api version' => [
                {   meta =>
                      { title => MetaInlines( [Plain list2content qw[A message] ] ) },
                    blocks => [
                        Header( 1, attributes {}, list2content qw[Hej Världen!] ),
                        Para list2content qw[Hur mår du idag?]
                    ],
                    'pandoc-api-version' => [0],
                }
            ],
        ],

    ],

    new_style => [
        [   'old-style with api-version' => [
                { title => MetaInlines( [Plain list2content qw[A message] ] ) },
                [   Header( 1, attributes {}, list2content qw[Hej Världen!] ),
                    Para list2content qw[Hur mår du idag?]
                ],
                api_version => '1.17.0.4',
            ],
        ],

        [   'new-style AST with api version' => [
                {   meta =>
                      { title => MetaInlines( [Plain list2content qw[A message] ] ) },
                    blocks => [
                        Header( 1, attributes {}, list2content qw[Hej Världen!] ),
                        Para list2content qw[Hur mår du idag?]
                    ],
                    'pandoc-api-version' => [ 1, 17, 0, 4 ],
                }
            ],
        ],

    ],

);

my %json = (
  'new_style' => '{"blocks":[{"c":[1,["",[],[]],[{"c":"Hej","t":"Str"},{"c":[],"t":"Space"},{"c":"V\u00e4rlden!","t":"Str"}]],"t":"Header"},{"c":[{"c":"Hur","t":"Str"},{"c":[],"t":"Space"},{"c":"m\u00e5r","t":"Str"},{"c":[],"t":"Space"},{"c":"du","t":"Str"},{"c":[],"t":"Space"},{"c":"idag?","t":"Str"}],"t":"Para"}],"meta":{"title":{"c":[{"c":[{"c":"A","t":"Str"},{"c":[],"t":"Space"},{"c":"message","t":"Str"}],"t":"Plain"}],"t":"MetaInlines"}},"pandoc-api-version":[1,17,0,4]}',
  'old_style' => '[{"unMeta":{"title":{"c":[{"c":[{"c":"A","t":"Str"},{"c":[],"t":"Space"},{"c":"message","t":"Str"}],"t":"Plain"}],"t":"MetaInlines"}}},[{"c":[1,["",[],[]],[{"c":"Hej","t":"Str"},{"c":[],"t":"Space"},{"c":"V\u00e4rlden!","t":"Str"}]],"t":"Header"},{"c":[{"c":"Hur","t":"Str"},{"c":[],"t":"Space"},{"c":"m\u00e5r","t":"Str"},{"c":[],"t":"Space"},{"c":"du","t":"Str"},{"c":[],"t":"Space"},{"c":"idag?","t":"Str"}],"t":"Para"}]]'
);

my @can_fields = qw[ meta blocks api_version ];

for my $style ( qw[ old_style new_style ] ) {
    subtest $style => sub {
        my $proto;
        subtest JSON => sub {
            lives_ok { $proto = pandoc_json $json{$style} } "pandoc_json";
            isa_ok $proto, 'Pandoc::Document', "isa document";
            isa_ok $proto, 'HASH',             "isa HASH";
        };
        my $expected = JSON->new->utf8->canonical->convert_blessed->encode( decode_json $json{$style} );
        for my $variant ( @{ $data{$style} } ) {
            my ( $name, $args ) = @$variant;
            my $doc;
            subtest $name => sub {
                lives_ok { $doc = Document @$args } "constructor";
                isa_ok $doc, 'Pandoc::Document', "isa document";
                is $doc->to_json, $expected, "to JSON";
                isa_ok $doc, 'HASH', "isa HASH";
                can_ok $doc, @can_fields;
                for my $field ( @can_fields ) {
                    is_deeply $doc->$field, $proto->$field, $field;
                }
                isa_ok $doc->api_version, 'Pandoc::Version', "api_version isa";
            };
        }
    };
}

throws_ok {
    Document { title => MetaInlines( [Plain list2content qw[A message] ] ) },
      [ Header( 1, attributes {}, list2content qw[Hej Världen!] ),
        Para list2content qw[Hur mår du idag?]
      ],
      '1.17.0.4';
} qr{Document: too many or ambiguous arguments}, 'invalid arguments';

done_testing;
