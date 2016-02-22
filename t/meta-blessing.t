use strict;
use Test::More 0.96;
use Pandoc::Elements;
use Scalar::Util qw[ blessed reftype ];

my $document = pandoc_json(<DATA>);

isa_ok $document, 'Pandoc::Document', "it's a document" or note ref $document;

my $counts = bless_check_loop($document->meta);

ok !keys(%$counts), 'no unblessed metadata objects' 
    or note "There were some unblessed metadata objects:\n", explain $counts;

sub bless_check_loop {
    my @data = @_;
    my %counts;
    LOOP:
    for ( my $i = 0; $i <= @data; $i++ ) {
        my $item = $data[$i];
        next LOOP unless reftype $item;
        if ( 'ARRAY' eq reftype $item ) {
            push @data, grep { reftype $_ } @$item;
        }
        elsif ( 'HASH' eq reftype $item ) {
            if ( $item->{t} ) {
                ++$counts{$item->{t}} unless blessed $item;
            }
            push @data, grep { reftype $_ } values %$item;
        }
    }
    return \%counts;
}


done_testing;

__DATA__
[{"unMeta":{"officia":{"t":"MetaInlines","c":[{"t":"Str","c":"molestias"}]},"error":{"t":"MetaMap","c":{"magni":{"t":"MetaInlines","c":[{"t":"Str","c":"repellendus"}]},"minima":{"t":"MetaList","c":[{"t":"MetaInlines","c":[{"t":"Str","c":"nihil"}]},{"t":"MetaMap","c":{"aliquam":{"t":"MetaInlines","c":[{"t":"Str","c":"voluptas"}]},"eos":{"t":"MetaInlines","c":[{"t":"Str","c":"odit"}]}}}]},"perferendis":{"t":"MetaInlines","c":[{"t":"Str","c":"aut"}]}}},"illo":{"t":"MetaList","c":[{"t":"MetaInlines","c":[{"t":"Str","c":"nesciunt"}]}]},"tempora":{"t":"MetaInlines","c":[{"t":"Str","c":"nisi"}]}}},[]]
