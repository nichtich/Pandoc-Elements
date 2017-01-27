use strict;
use Test::More;
use App::pod2pandoc qw(parse_arguments pod2pandoc);
use File::Temp qw(tempdir);
use File::Spec::Functions;
use Test::Output qw(:functions);
use File::stat;

is_deeply 
    [ parse_arguments(qw(foo --bar doz --baz --wiki)) ],
    [ ['foo'], { wiki => 1 }, qw(--bar doz --baz) ], 'parse_arguments';

is_deeply 
    [ parse_arguments(qw(foo -- doz --baz --wiki)) ],
    [ ['foo'], { }, qw(doz --baz --wiki) ], 'parse_arguments';


unless ($ENV{RELEASE_TESTING}) {
    note 'Skipping more tests for RELEASE_TESTING';
    done_testing;
    exit;
}

my $dir = tempdir(CLEANUP => 1);
my $target = catfile($dir, 'Pandoc-Elements.html');
sub slurp { local (@ARGV, $/) = @_; <> }


# convert a single file
my @source = 'lib/Pandoc/Elements.pm';
pod2pandoc( \@source, -o => $target, '--template' => 't/template.html' );

is slurp($target), "Pandoc::Elements: create and process Pandoc documents\n".
                   ": lib/Pandoc/Elements.pm\n", 'pod2pandoc single file';


# convert multiple files
unshift @source, 'lib/Pod/Simple/Pandoc.pm';
pod2pandoc( \@source, -o => $target, '--template' => 't/template.html' );

is slurp($target), "Pod::Simple::Pandoc: convert Pod to Pandoc document model\n".
                   ": lib/Pod/Simple/Pandoc.pm, lib/Pandoc/Elements.pm\n", 
                   'pod2pandoc multiple files';

#my $mtime = stat($target)->[9];

# convert directory

my ($stdout, $stderr) = output_from {
    pod2pandoc( ['lib/', 't', $dir], {'ext' => 'md', wiki => 1, update => 1} );
};
is( (scalar split "\n", $stdout), 13, 'pod2pandoc directory');
is $stderr, "no .pm or .pod files found in t\n", 'warning';

ok -e catfile($dir, 'Pod-Simple-Pandoc.md'), 'option wiki';

# TODO: test passes although not implemented
#is stat($target)->[9], $mtime, 'option update';

done_testing;
