package Pandoc::Filter::Lazy;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.14';

use parent 'Pandoc::Filter';

use Pandoc::Elements;

sub new {
    my ( $class, $args ) = @_;
    my $filter = eval 
        "use Pandoc::Elements;use Pandoc::Walker;Pandoc::Walker::action($args)";
    my $self = bless {
        arguments => $args,
        action    => $filter,
        error     => $filter ? '' : $@,
    }, $class;
}

sub code {
    my $arguments = shift->{arguments};
    my %opt       = @_;
    my $function  = $opt{function} || 'Pandoc::Filter->new';
    my $code      = <<CODE;
use 5.010;
use strict;
use warnings;
use Pandoc::Filter;
use Pandoc::Elements;

$function( $arguments );
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
 
=head1 METHODS

In addition to the methods inherited from L<Pandoc::Filter>:

=head2 error

=head2 code

=cut
