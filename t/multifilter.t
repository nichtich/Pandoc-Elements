use strict;
use Test::More;
use Test::Exception;
use Pandoc::Elements;
use Pandoc::Filter::Multifilter qw(find_filter apply_filter);
use IPC::Cmd 'can_run';

{
    my @tests = (
        [ Document {}, [] ] 
            => [], 'empty multifilter',
        [qw(foo bar)] 
            => [qw(foo bar)], 'list of filters',
        [ Document { multifilter => MetaList [
            MetaInlines [ Str 'hello', Space, Str "world" ],
            MetaInlines [ Str 'foo' ], ] }, [] ] 
            => ['hello world', 'foo'], 'multifilter field',
    );

    while (@tests) {
        my $multifilter = Pandoc::Filter::Multifilter->new(@{ shift @tests });
        is_deeply [$multifilter->names], shift @tests, shift @tests;
    }
}

{
    my @tests = (
        ['script/multifilter'] 
            => ['script/multifilter'], 'absolute path',
        ['t/pandoc/filters/empty.pl'] 
            => ['perl', 't/pandoc/filters/empty.pl'], 'known extension',
        ['perl']
            => [can_run('perl')], 'executable in $PATH',
    );

    local $ENV{HOME} = 't';
    if (-e 't/.pandoc') { # only in git repository
        push @tests, (
            ['empty.pl'] 
                 => ['perl', 't/.pandoc/filters/empty.pl'], 'known extension in DATA_DIR',
            ['caps'] 
                => ['t/.pandoc/filters/caps'], 'executable in DATA_DIR',
        );
    }

    while (@tests) {
        my @filter = find_filter(@{shift @tests});
        is_deeply \@filter, shift @tests, join ' ', 'find_filter: '.shift @tests;
    }

    my $notfound = '0c9703d020ded30c97682e812636c9ef';
    throws_ok { find_filter($notfound) } qr/^filter not found: $notfound/;
}

if ( $ENV{RELEASE_TESTING} and
     (`pandoc -v` // '') =~ /^pandoc (\d+)\.(\d+)/ and ($1 > 1 or $2 >= 12) ) {

    my $in = Document {}, [ Para [ Str 'hi' ] ];

    my $out = apply_filter($in, 'html', find_filter('caps','t/pandoc'));
    is $out->string, 'HI', 'apply_filter';

    throws_ok {
        apply_filter($in, 'html', find_filter('empty.pl','t/pandoc'));
    } qr{^filter emitted no valid JSON};

    $in->meta({ multifilter => MetaList [ MetaInlines [ Str 'caps' ] ] });
    my $filter = Pandoc::Filter::Multifilter->new('t/pandoc/filters/caps');

    if (-e 't/.pandoc') { # only in git repository
        local $ENV{HOME} = 't';
        $filter->apply($in)->to_json;
        is $in->string, 'HI', 'apply_filter';
    }

} else { 
    note "Skipping detailed testing of Pandoc::Filter::Multifilter";
}

done_testing;
