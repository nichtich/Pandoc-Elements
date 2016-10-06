package Pandoc::Filter::Multifilter;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.24';

use parent 'Pandoc::Filter';
our @EXPORT_OK = (qw(find_filter apply_filter));

use Pandoc::Elements 'pandoc_json';
use Scalar::Util 'blessed';
use IPC::Cmd 'can_run';
use IPC::Run3;

sub new {
    my ($class, @names) = @_;

    if (blessed $names[0] and $names[0]->isa('Pandoc::Document')) {
        my $metalist = $names[0]->meta->{multifilter};
        @names = ();
        if ( $metalist and $metalist->name eq 'MetaList' ) {
            @names = map { $_->metavalue } @{$metalist->content};
        }
    }

    bless { names => \@names }, $class;
}

sub names {
    @{$_[0]->{names}}
}

sub apply {
    my ( $self, $doc, $format, $meta ) = @_;
	return $doc if $doc->name ne 'Document';
	
	my @filters = map { [ find_filter($_) ] }
		$self->names, 
		Pandoc::Filter::Multifilter->new( $meta ? Document($meta, []) : $doc )->names;

    foreach my $filter (@filters) {
    	$doc = apply_filter($doc, $format, @$filter);
    }

	# modify original document 
	$_[1]->meta($doc->meta);
	$_[1]->content($doc->content);
 
    $doc;
}

our %SCRIPTS = (
    hs => 'runhaskell',
    js => 'node',
    php => 'php',
    pl => 'perl',
    py => 'python',
    rb => 'ruby',
);

sub find_filter {
    my $name = shift;
    my $data_dir = shift // $ENV{HOME} . '/.pandoc';
    $data_dir =~ s|/$||;

    foreach my $filter ("$data_dir/filters/$name", $name) {
        return $filter if -x $filter;
        if (-e $filter and $filter =~ /\.([a-z]+)$/i) {
            if ( my $cmd = $SCRIPTS{lc($1)} ) {
                die "cannot execute filter with $cmd\n" unless can_run($cmd);
                return ($cmd, $filter);
            }
        }
    }

    return (can_run($name) or die "filter not found: $name\n");
}

sub apply_filter {
    my ($doc, $format, @filter) = @_;

    my $stdin  = $doc->to_json;
    my $stdout = "";
    my $stderr = "";

    run3 [@filter, $format // ''], \$stdin, \$stdout, \$stderr;
    if ($?) {
        $stderr .= "\n" if $stderr ne '' and $stderr !~ /\n\z/s;
        die join(' ','filter failed:',@filter)."\n$stderr";
    }

    eval { $doc = pandoc_json($stdout) };
    die join(' ','filter emitted no valid JSON:',@filter)."\n" if $@;

    return $doc;
}

__END__

=head1 NAME

Pandoc::Filter::Multifilter - applies filters from metadata field C<multifilter>

=head1 SYNOPSIS

    # as executable
    pandoc -F multifilter ...

    # as part of other code
    $filter = Pandoc::Filter::Multifilter->new('foo','./bar/doz');
    $filter->apply($ast);

=head1 METHODS

=head2 new( $document | @names )

Create a new multifilter with filters either listed in document metadata field
C<multifilter> or given as list of strings.

=head2 names

Return the list of filter names as specified.

=head2 apply( $doc [, $format [, $metadata ] ] )

Apply all filters specified on instantiation plus filters in document metadata
field C<metafilters>.

=head1 FUNCTIONS

=head2 find_filter( $name [, $DATA_DIR ] )

Find a filter by its name an an optional Pandoc C<$DATA_DIR> (C<~/.pandoc> by
default). Returns a list of command line arguments to execute the filter or
throw an exception.

=head2 apply_filter( $doc, $format, @command )

Apply a filter, given by its command line arguments, to a Pandoc
L<Document|Pandoc::Elements/Document> element and return a transformed
Document or throw an exception on error. Can be called like this:

  apply_filter( $doc, $format, find_filter( $name ) );

=head1 SEE ALSO

This filter is provided as system-wide executable L<multifilter>, see there for
additional documentation.

=cut
