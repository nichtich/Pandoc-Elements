package Pod::Simple::Pandoc;
use strict;
use warnings;
use 5.010;

our $VERSION = '0.11_01';

use Pod::Simple::SimpleTree;
use Pandoc::Elements;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub _parser {
    my $self = shift;

    my $parser = Pod::Simple::SimpleTree->new;
    $parser->nix_X_codes(1);         # ignore X<...> codes
    $parser->parse_empty_lists(0);   # ignore empty lists
    $parser->nbsp_for_S(1);          # map S<...> to U+00A0 (non-breaking space)
    $parser->merge_text(1);          # emit text nodes combined
    $parser->no_errata_section(1);   # omit errata section
    $parser->complain_stderr(1);     # TODO: configure
    $parser->accept_targets('*');    # TODO

    # remove shortest leading whitespace string from verbatim sections
    $parser->strip_verbatim_indent(
        sub {
            my $indent = length $_[0][1];
            for ( @{ $_[0] } ) {
                $_ =~ /^(\s*)/;
                $indent = length($1) if length($1) < $indent;
            }
            ' ' x $indent;
        }
    );

    return $parser;
}

sub parse_file {
    my ( $self, $file ) = @_;
    $self->parse_tree( $self->_parser->parse_file($file)->root );
}

sub parse_string {
    my ( $self, $string ) = @_;
    $self->parse_tree( $self->_parser->parse_content($string)->root );
}

sub parse_tree {
    my ( $self, $tree ) = @_;
    _pod_element($tree);
}

my %POD_ELEMENT_TYPES = (
    Document => sub {
        Document {}, [ _pod_content( $_[0] ) ];
    },
    Para => sub {
        Para [ _pod_content( $_[0] ) ];
    },
    I => sub {
        Emph [ _pod_content( $_[0] ) ];
    },
    B => sub {
        Strong [ _pod_content( $_[0] ) ];
    },
    C => sub {
        my $code = _pod_content( $_[0] );
        Code attributes {}, _pod_flatten( $_[0] );
    },
    F => sub {
        Code attributes { classes => ['filename'] }, _pod_flatten( $_[0] );
    },
    L => sub {
        use Data::Dumper;
        my $type    = $_[0][1]{type};
        my $to      = $_[0][1]{to};
        my $section = $_[0][1]{section};
        my $url     = '';

        if ( $type eq 'url' ) {
            $url = "$to";
        }
        elsif ( $type eq 'man' ) {
            if ( $to =~ /^([^(]+)(?:[(](\d+)[)])?$/ ) {

            # TODO: configure MAN_URL, e.g.
            # http://man7.org/linux/man-pages/man{section}/{name}.{section}.html
                $url = "http://linux.die.net/man/$2/$1";

                # TODO: add section to URL if given
            }
        }
        elsif ( $type eq 'pod' ) {
            if ($to) {

                # TODO: configure PERLDOC_URL
                $url = "https://metacpan.org/pod/$to";
            }
            if ($section) {

                # TODO: further escaping
                $section =~ s/ /-/g;
                $url .= "#$section";
            }
        }

        return Link [ _pod_content( $_[0] ) ], [ $url, '' ];
    },
    head1 => sub {
        Header 1, attributes {}, [ _pod_content( $_[0] ) ];
    },
    head2 => sub {
        Header 2, attributes {}, [ _pod_content( $_[0] ) ];
    },
    head3 => sub {
        Header 3, attributes {}, [ _pod_content( $_[0] ) ];
    },
    head4 => sub {
        Header 4, attributes {}, [ _pod_content( $_[0] ) ];
    },
    Verbatim => sub {
        CodeBlock attributes {}, _pod_flatten( $_[0] );
    },
    'over-bullet' => sub {
        BulletList [ _pod_list( $_[0] ) ];
    },
    'over-number' => sub {
        OrderedList [ 1, DefaultStyle, DefaultDelim ], [ _pod_list( $_[0] ) ];
    },
    'over-text' => sub {
        DefinitionList [ _pod_list( $_[0] ) ];
    },
    'over-block' => sub {
        BlockQuote [ _pod_content( $_[0] ) ];
    },

    # TODO: for/Data
);

sub _pod_list {
    my ($element) = @_;
    my $length = scalar @$element;

    my $deflist = $element->[2][0] eq 'item-text';
    my @list;
    my $item = [];

    my $push_item = sub {
        return unless @$item;
        if ($deflist) {
            my $term = shift @$item;
            push @list, [ $term->content, [$item] ];
        }
        else {
            push @list, $item;
        }
    };

    foreach my $e ( @$element[ 2 .. $length - 1 ] ) {
        my $type = $e->[0];
        if ( $type =~ /^item-(number|bullet|text)$/ ) {
            $push_item->();
            $item = [ Plain [ _pod_content($e) ] ];
        }
        else {
            if ( @$item == 1 and $item->[0]->name eq 'Plain' ) {

                # first block element in item should better be Paragraph
                $item->[0] = Para $item->[0]->content;
            }
            push @$item, _pod_element($e);
        }
    }
    $push_item->();

    # BulletList/OrderedList: [ @blocks ], ...
    # DefinitionList: [ [ @inlines ], [ @blocks ] ], ...
    return @list;
}

sub _pod_element {
    my ($element) = @_;

    if ( ref $element ) {
        my $type = $POD_ELEMENT_TYPES{ $element->[0] } or return;
        $type->($element);
    }
    else {
        # TODO: replace spaces!
        return Str $element;
    }
}

# stringify
sub _pod_flatten {

    my $string = '';
    my $walk;
    $walk = sub {
        my ($element) = @_;
        my $n = scalar @$element;
        for ( @$element[ 2 .. $n - 1 ] ) {
            if ( ref $_ ) {
                $walk->($_);
            }
            else {
                $string .= $_;
            }
        }
    };
    $walk->( $_[0] );

    return $string;
}

# map the content of a Pod element to a list
sub _pod_content {
    my ($element) = @_;
    my $length = scalar @$element;
    map { _pod_element($_) } @$element[ 2 .. $length - 1 ];
}

1;
__END__

=encoding utf-8

=head1 NAME

Pod::Simple::Pandoc - convert Pod to Pandoc document model 

=head1 SYNOPSIS

  use Pod::Simple::Pandoc;

  my $parser = Pod::Simple::Pandoc->new;
  my $doc    = $parser->parse_file( $pod_filename );
  
  print $doc->to_json;

=head1 METHODS

=head2 parse_file( $filename | *INPUT )

=head2 parse_string( $string )

=head1 SEE ALSO

L<Pod::Simple>

=cut
