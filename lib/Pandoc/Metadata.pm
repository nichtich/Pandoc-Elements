package Pandoc::Metadata;
use strict;
use warnings;
use 5.010001;

use Pandoc::Elements;
use Scalar::Util qw(blessed reftype);
use JSON::PP;
use Carp;

# packages and methods

{
    # key-value map of metadata fields
    package Pandoc::Document::Metadata;

    {
        no warnings 'once';
        *to_json = \&Pandoc::Document::Element::to_json;
    }

    sub TO_JSON {
        return { map { $_ => $_[0]->{$_} } keys %{ $_[0] } };
    }

    sub value {
        my $map = { c => shift };
        Pandoc::Document::MetaMap::value( $map, @_ )
    }
}

{
    # metadata element parent class
    package Pandoc::Document::Meta;
    our @ISA = ('Pandoc::Document::Element');
    sub is_meta { 1 }
    sub value { shift->value(@_) }
}

# helpers

sub _pointer_token {
    state $valid_pointer_re = qr{ \A (?: [^/] .* | (?: / [^/]* )* ) \z }msx;
    state $token_re = qr{
        \A
        (?<_last_pointer>
            (?<_ref_token>
                (?<_old_style>
                    (?<_key> [^/] .* \z )    # "key" -- old-style
                )
            |   / (?<_key> [^/]* ) # "/key"
            |     (?<_empty> \z )  # "" -- return current element
            )
            (?<_pointer> / .* \z | )
        )
        \z
    }msx;
    # set non-participating keys to undef
    state $defaults = {
        map {; $_ => undef } qw( _last_pointer _ref_token _old_style _key _empty _pointer )
    };
    my %opts = @_;
    $opts{_pointer} //= $opts{_full_pointer} //= $opts{pointer} //= "";
    $opts{_pointer} =~ $valid_pointer_re
      // croak( sprintf 'Invalid (sub)pointer: "%s" in pointer "%s"',
        @opts{qw[ _pointer _full_pointer ]} );
    $opts{_pointer} =~ $token_re; # guaranteed to match since validation matched!
    my %match = %+;
    unless ( grep { defined $_ } @match{qw[_old_style _empty]} ) {
        $match{_key} =~ s!\~1!/!g;
        $match{_key} =~ s!\~0!~!g;
    }
    return ( %opts, %$defaults, %match );
}

sub _handle_bad_pointer {
    my ( %opts ) = @_;
    return unless $opts{strict};
    %opts = _pointer_token( %opts );
    croak( sprintf 'No list or mapping "%s" in (sub)pointer "%s" in  pointer "%s"',
        @opts{qw[ _ref_token _last_pointer _full_pointer ]} );
}

# methods

sub _value_args {
    my $content = shift->{c};
    my ($pointer, %opts) = @_ % 2 ? @_ : (undef, @_);

    $opts{_pointer} = $pointer // $opts{_pointer} // $opts{pointer} // '';
    $opts{_full_pointer} //= $opts{_pointer};

    return ($content, %opts);
}

sub Pandoc::Document::MetaString::value {
    my ($content, %opts) = _value_args(@_);
    $opts{_pointer} eq '' ? $content : _handle_bad_pointer(%opts);
}

sub Pandoc::Document::MetaBool::set_content {
    $_[0]->{c} = $_[1] && $_[1] ne 'false' && $_[1] ne 'FALSE' ? 1 : 0;
}

sub Pandoc::Document::MetaBool::TO_JSON {
    return {
        t => 'MetaBool',
        c => $_[0]->{c} ? JSON::true() : JSON::false(),
    };
}

sub Pandoc::Document::MetaBool::value {
    my ($content, %opts) = _value_args(@_);
    return _handle_bad_pointer(%opts) if $opts{_pointer} ne '';

    if (($opts{boolean} // '') eq 'JSON::PP') {
        $content ? JSON::true() : JSON::false();
    } else {
        $content ? 1 : 0;
    }
}

sub Pandoc::Document::MetaMap::value {
    my ($map, %opts) = _value_args(@_);
    %opts = _pointer_token(%opts);
    if ( defined $opts{_empty} ) {
        return { map { $_ => $map->{$_}->value(%opts) } keys %$map };
    } else {
        return exists($map->{$opts{_key}}) ? $map->{$opts{_key}}->value(%opts)
        : $opts{strict} ? croak(
            sprintf 'Node "%s" doesn\'t correspond to any key in (sub)pointer "%s" in pointer "%s"',
                @opts{qw[_ref_token _last_pointer _full_pointer]} )
        : undef;
    }
}

sub Pandoc::Document::MetaList::value {
    my ($content, %opts) = _value_args(@_);
    %opts = _pointer_token(%opts);
    if ( defined $opts{_empty} ) {
        return [ map { $_->value(%opts) } @$content ]
    }
    elsif ($opts{_key} =~ /^[1-9]*[0-9]$/) {
        if ( $opts{_key} > $#$content ) {
            return undef unless $opts{strict};
            croak sprintf 'List index %s out of range in (sub)pointer "%s" in pointer "%s"',
                @opts{qw(_key _last_pointer _full_pointer)};
        }
        my $value = $content->[$opts{_key}];
        return defined($value) ? $value->value(%opts) : undef;
    }
    elsif ($opts{strict}) {
        croak sprintf 'Node "%s" not a valid list index in (sub)pointer "%s" in pointer "%s"',
            $opts{_ref_token}, $opts{_last_pointer}, $opts{_full_pointer};
    } else {
        return undef;
    }
}

sub Pandoc::Document::MetaInlines::value {
    my ($content, %opts) = _value_args(@_);
    return _handle_bad_pointer(%opts) if $opts{_pointer} ne '';

    if ($opts{element} // '' eq 'keep') {
        $content;
    } else {
        join '', map { $_->string } @$content;
    }
}

sub Pandoc::Document::MetaBlocks::string {
    join "\n\n", map { $_->string } @{$_[0]->content};
}

sub Pandoc::Document::MetaBlocks::value {
    my ($content, %opts) = _value_args(@_);
    return _handle_bad_pointer(%opts) if $opts{_pointer} ne '';

    if ($opts{element} // '' eq 'keep') {
        $content;
    } else {
        $_[0]->string;
    }
}

1;
__END__

=head1 NAME

Pandoc::Metadata - pandoc document metadata

=head1 DESCRIPTION

Document metadata such as author, title, and date can be embedded in different
documents formats. Metadata can be provided in Pandoc markdown format with
L<metadata blocks|http://pandoc.org/MANUAL.html#metadata-blocks> at the top of
a markdown file or in YAML format like this:

  ---
  title: a title
  author:
    - first author
    - second author
  published: true
  ...

Pandoc supports document metadata build of strings (L</MetaString>), boolean
values (L</MetaBool>), lists (L</MetaList>), key-value maps (L</MetaMap>),
lists of inline elements (L</MetaInlines>) and lists of block elements
(L</MetaBlocks>). Simple strings and boolean values can also be specified via
pandoc command line option C<-M> or C<--metadata>:

  pandoc -M key=string
  pandoc -M key=false
  pandoc -M key=true
  pandoc -M key

Perl module L<Pandoc::Elements> exports functions to construct metadata
elements in the internal document model and the general helper function
C<metadata>.

=head1 COMMON METHODS

All Metadata Elements support L<common element methods|Pandoc::Elements/COMMON
METHODS> (C<name>, C<to_json>, C<string>, ...) and return true for method
C<is_meta>.

=head2 value( [ $pointer ] [ %options ] )

Called without an argument this method returns an unblessed deep copy of the
metadata element. JSON Pointer (L<RFC 6901|http://tools.ietf.org/html/rfc6901>)
expressions can be used to select subfields.  Note that JSON Pointer escapes
slash as C<~1> and character C<~> as C<~0>. URI Fragment syntax is not supported.

For backwards compatibility C<$pointer> may start with a character other than C</>.
In that case the whole C<$pointer> string is taken to be a key at the root level,
and no JSON Pointer escapes are recognised. Older programs expecting root level
keys starting with C</> or the empty string as key will have to be updated to
use JSON Pointer syntax.

  $doc->value;                   # full metadata
  $doc->value("");               # full metadata, explicitly
  $doc->value('/author');        # author field
  $doc->value('author');         # author field, old-style
  $doc->value('/author/name');   # name subfield of author field
  $doc->value('/author/0');      # first author field
  $doc->value('/author/0/name'); # name subfield of first author field
  $doc->value('/~1~0');          # metadata field '/~'
  $doc->value('/');              # field with empty string as key

Returns C<undef> if the selected field does not exist.

As a debugging aid you can set option C<strict> to a true value.
In this case the method will C<croak> if an invalid pointer,
invalid array index, non-existing key or non-existing array index
is encountered.

Instances of MetaInlines and MetaBlocks are stringified by unless option
C<element> is set to C<keep>.

Setting option C<boolean> to C<JSON::PP> will return C<JSON::PP:true>
or C<JSON::PP::false> for L<MetaBool|/MetaBool> instances.

=head1 METADATA ELEMENTS

=head2 MetaString

A plain text string metadata value.

    MetaString $string
    metadata "$string"

=head2 MetaBool

A Boolean metadata value. The special values C<"false"> and
C<"FALSE"> are recognized as false in addition to normal false values (C<0>,
C<undef>, C<"">, ...).

    MetaBool $value
    metadata JSON::true()
    metadata JSON::false()

=head2 MetaList

A list of other metadata elements.

    MetaList [ @values ]
    metadata [ @values ]

=head2 MetaMap

A map of keys to other metadata elements.

    MetaMap { %map }
    metadata { %map }

=head2 MetaInlines

Container for a list of L<inlines|Pandoc::Elements/INLINE ELEMENTS> in
metadata.

    MetaInlines [ @inlines ]

=head2 MetaBlocks

Container for a list of L<blocks|Pandoc::Elements/BLOCK ELEMENTS> in metadata.

    MetaBlocks [ @blocks ]

The C<string> method concatenates all stringified content blocks separated by
empty lines.

=cut
