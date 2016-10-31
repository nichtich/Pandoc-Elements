use strict;
use Test::More 0.96; # for subtests
use Pandoc::Elements;

use constant AV => 'Pandoc::Document::ApiVersion';


my %objects = (
    from_array  => new_ok( AV, [ [ 1, 17, 0, 4 ] ], 'new from array'),
    from_list   => new_ok( AV, [ ( 1, 17, 0, 4 ) ], 'new from list'),
    from_string => new_ok( AV, ['1.17.0.4'], 'new from string'),
);

my $standard = bless( [ 1, 17, 0, 4 ], 'Pandoc::Document::ApiVersion' );

for my $name ( sort keys %objects ) {
    is_deeply $objects{ $name }->TO_JSON, $standard->TO_JSON, "$name structure";
}

my %compared = (
    empty  => {
        object => new_ok( AV, [], 'new empty'),
        api => "",
        exe => '1.12',
    },
    lesser => {
        object => new_ok( AV, [ [ 1, 16 ] ], 'new lesser'),
        api => '1.16',
    },
    more => {
        object => $standard,
        api => '1.17.0.4',
        exe => '1.18',
    }
);

for my $name ( sort keys %compared ) {
    ok $compared{$name}{object}->EQ($compared{$name}{api}), "$name API";
    if ( $compared{$name}{exe} ) {
        ok $compared{$name}{object}->eq($compared{$name}{exe}), "$name executable";
    }
    ok $compared{$name}{object}->LE($standard), "$name LE standard";

    ok $standard->GE($compared{$name}{api}), "standard GE $name";
    ok $standard->ge($compared{$name}{exe}), "standard ge $name";

    # note explain $compared{$name}{object}; 
}

is_deeply $standard->TO_JSON, [ 1, 17, 0, 4 ], 'TO_JSON';

done_testing;
