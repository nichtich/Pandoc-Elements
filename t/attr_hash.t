use strict;
use v5.10;
use Test::More 0.96;
use Pandoc::Elements;
# use Hash::MultiValue;

for my $has_class ( 0, 1 ) {
    my $name = $has_class ? 'with classes' : 'without classes';
    subtest $name => sub {
        my $data = +{ id => !!$has_class, map {; ( "key-$has_class-$_" => "val-$has_class-$_" ) } qw[ a b c ] };
        if ( $has_class ) {
            $data->{class} = [ map {; "class-$_" } 0 .. 2 ];
        }
        my $elem = Code attributes $data, $name;
        isa_ok my $attr_hash = $elem->attr_hash, 'Hash::MultiValue';
        subtest 'check all keys' => sub {
            for my $key ( sort keys %$data ) {
                ok exists $attr_hash->{$key}, "exists $key";
            }
        };
        ok exists $attr_hash->{class} == $has_class, "has classes: $has_class";
        isnt $attr_hash->get('id'), $elem->keyvals->get('id'), 'attr_hash vs. keyvals';
        is_deeply $attr_hash->as_hashref_mixed, $data, "deep comparison",
            or note explain +{ data => $data, attr => $elem->attr, hmv => $attr_hash->as_hashref_mixed };
    };
}


done_testing;

__END__
