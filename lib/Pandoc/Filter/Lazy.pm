package Pandoc::Filter::Lazy;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.24';

use parent 'Pandoc::Filter';

use Pandoc::Elements;

sub new {
    my ( $class, $script ) = @_;
    $script =~ s/^\s+|\s+$//g;

    if ( $script =~ /^(.*?)\s*=>\s*(.+)$/ ) {
        my ( $selector, $action ) = ( $1, $2 );
        if ( $selector =~ /[^a-z]/i && $selector !~ /^["']/ ) {
            $selector = "'$selector'";
        }
        if ( $action !~ /^sub\s*{/ ) {
            $action = "sub { $action }";
        }
        $script = "$selector => $action";
    }

    my $filter =
      "use Pandoc::Elements;use Pandoc::Walker;Pandoc::Walker::action($script)";
    $filter = eval $filter;    ## no critic
    my $self = bless {
        script => $script,
        action => $filter,
        error  => $filter ? '' : $@,
    }, $class;
}

sub script {
    shift->{script};
}

sub code {
    my $script   = shift->script;
    my %opt      = @_;
    my $function = $opt{function} || 'Pandoc::Filter->new';
    my $code     = <<CODE;
use 5.010;
use strict;
use warnings;
use Pandoc::Filter;
use Pandoc::Elements;

$function( $script );
CODE

    $code = join "\n", map { $opt{indent} . $_ } split "\n", $code
      if $opt{indent};

    return $code;
}

=head1 NAME

Pandoc::Filter::Lazy - facilitate creation of filters

=head1 SYNOPSIS

  my $filter = Pandoc::Filter::Lazy->new(
      'Header => sub { Header $_->level, [ Str $_->string ] }'
  );
  if ( $filter->error ) {
      say STDERR $lazy->error;
      say STDERR $lazy->code;
  } else {
      $filter->apply(...)
  }
 
=head1 DESCRIPTION

This module helps creation of L<Pandoc::Filter> with arguments given as string.
The following should result in equivalent filters:

  Pandoc::Walker::action( ... );     #  ...  as code
  Pandoc::Filter::Lazy->new( '...' ) # '...' as string

The script passed as only argument is tried to convert to valid Perl by escaping
selectors and adding a missing C<sub { ... }">, for instance

  Code|CodeBlock => say $_->class

Is converted to

  'Code|CodeBlock' => sub { say $_->class }

=head1 METHODS

In addition to the methods inherited from L<Pandoc::Filter>:

=head2 error

Return an error message if compilation of the filter failed.

=head2 script

Return the (possibly cleaned) script arguments to create the filter.

=head2 code( [ indent => $indent, ] [ function => $function ] )

Return a string of Perl code that can be used to create the same filter.

=head1 SEE ALSO

This module is used in command line scripts L<pandocwalk> and L<pod2pandoc>.

=cut
