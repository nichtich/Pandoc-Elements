package Pandoc::Elements;
use strict;
use warnings;
use 5.010;

use utf8; # because of non-breaking spaces in line blocks

our $VERSION = '0.25';

# Declare these early so they can be used as barewords in this file
# FIXME: Yet they can't!
use subs qw( PANDOC_VERSION PANDOC_API_VERSION PANDOC_LATEST_API_VERSION );

our $PANDOC_VERSION;            # a string like '1.16'
our $PANDOC_API_VERSION;        # a string like '1.17.0.4'
our %PANDOC_API_VERSION_OF;     # maps pandoc versions to api versions
our $PANDOC_EXE_VERSION_OF;     # a Hash::MultiValue mapping api versions to pandoc executable versions versions
our $PANDOC_LATEST_API_VERSION; # holds the highest value in %PANDOC_API_VERSION_OF

use Pandoc::Version;
use Hash::MultiValue 0.16;

$PANDOC_VERSION ||= $ENV{PANDOC_VERSION};

# This must be updated for each pandoc version >= 1.18
%PANDOC_API_VERSION_OF = (
    ## Shall give undef for pandoc < 1.18!
    '1.18' => '1.17.0.4',
);

{
    # Even though there is as yet only one version pair our API
    # should be prepared for the future: the mapping from pandoc-api-
    # versions to pandoc executable versions will probably be
    # one-to-many.

    # I wish there were a Hash::MultiValue where the values were
    # automatically sorted, and which could be made readonly! BPJ

    my $sort_versions = sub {
        ## XXX: should the values be objects? The keys can't be anyway so probably not.
        map { $_->string } sort { $a <=> $b } map { Pandoc::Version->new( $_ ) } @_;
    };

    # Work around Hash::MultiValue's preservation of the order of
    # existing keys/values by feeding the sorted values to an
    # instance where the keys/values didn't exist before. We want
    # them sorted in particular so that the last value is the last
    # pandoc version (to date) which used each API version.

    my $pvo_temp = Hash::MultiValue->new( reverse %PANDOC_API_VERSION_OF );
    $PANDOC_EXE_VERSION_OF = Hash::MultiValue->new;
    for my $key ( $sort_versions->( $pvo_temp->keys ) ) {
        $PANDOC_EXE_VERSION_OF->set( $key,
            $sort_versions->( $pvo_temp->get_all( $key ) ) );
    }
    $PANDOC_LATEST_API_VERSION = ($PANDOC_EXE_VERSION_OF->keys)[-1];
}

# This is actually trivalent:
# * Undefined/env var unset: assume pandoc >= 1.18
# * Defined but false: assume pandoc < 1.18
# * True: assume the value is the version to use
$PANDOC_API_VERSION //= $ENV{PANDOC_API_VERSION} // $PANDOC_API_VERSION_OF{$PANDOC_VERSION // ''};

# Functions which return Pandoc::Version objects from their like-named package variables
# They are uppercase because the variables are, and because the lowercase
# pandoc_version() function does something else: wraps Pandoc::Version->new()

# FIXME: Make Pandoc::Version::cmp() treat empty input as zero?

sub PANDOC_VERSION { Pandoc::Version->new( $PANDOC_VERSION // return ) }
sub PANDOC_API_VERSION { Pandoc::Version->new( $PANDOC_API_VERSION // return ) }
sub PANDOC_LATEST_API_VERSION { Pandoc::Version->new( $PANDOC_LATEST_API_VERSION // return ) }

our %ELEMENTS = (

    # BLOCK ELEMENTS
    Plain          => [ Block => 'content' ],
    Para           => [ Block => 'content' ],
    CodeBlock      => [ Block => qw(attr content) ],
    RawBlock       => [ Block => qw(format content) ],
    BlockQuote     => [ Block => 'content' ],
    OrderedList    => [ Block => qw(attr content/items) ],
    BulletList     => [ Block => 'content/items' ],
    DefinitionList => [ Block => 'content/items:[DefinitionPair]' ],
    Header         => [ Block => qw(level attr content) ],
    HorizontalRule => ['Block'],
    Table          => [ Block => qw(caption alignment widths headers rows) ],
    Div            => [ Block => qw(attr content) ],
    Null           => ['Block'],
    LineBlock      => [ Block => qw(content/lines) ],

    # INLINE ELEMENTS
    Str         => [ Inline => 'content' ],
    Emph        => [ Inline => 'content' ],
    Strong      => [ Inline => 'content' ],
    Strikeout   => [ Inline => 'content' ],
    Superscript => [ Inline => 'content' ],
    Subscript   => [ Inline => 'content' ],
    SmallCaps   => [ Inline => 'content' ],
    Quoted      => [ Inline => qw(type content) ],
    Cite        => [ Inline => qw(citations content) ],
    Code        => [ Inline => qw(attr content) ],
    Space       => ['Inline'],
    SoftBreak   => ['Inline'],
    LineBreak   => ['Inline'],
    Math        => [ Inline => qw(type content) ],
    RawInline   => [ Inline => qw(format content) ],
    Link        => [ Inline => qw(attr content target) ],
    Image       => [ Inline => qw(attr content target) ],
    Note        => [ Inline => 'content' ],
    Span        => [ Inline => qw(attr content) ],

    # METADATA ELEMENTS
    MetaBool    => [ Meta => 'content' ],
    MetaString  => [ Meta => 'content' ],
    MetaMap     => [ Meta => 'content' ],
    MetaInlines => [ Meta => 'content' ],
    MetaList    => [ Meta => 'content' ],
    MetaBlocks  => [ Meta => 'content' ],
);

# type constructors
foreach (
    qw(DefaultDelim Period OneParen TwoParens SingleQuote DoubleQuote
    DisplayMath InlineMath AuthorInText SuppressAuthor NormalCitation
    AlignLeft AlignRight AlignCenter AlignDefault DefaultStyle Example
    Decimal LowerRoman UpperRoman LowerAlpha UpperAlpha)
  )
{
    $ELEMENTS{$_} = ['Inline'];
}

use Carp;
use JSON qw(decode_json);
use Scalar::Util qw(blessed reftype);
use Pandoc::Walker qw(walk);

use parent 'Exporter';
our @EXPORT = (
    keys %ELEMENTS,
    qw(Document attributes metadata citation pandoc_json pandoc_query),
    qw(pandoc_version pandoc_api_version_of pandoc_exe_version_of),
    qw(PANDOC_VERSION PANDOC_API_VERSION PANDOC_LATEST_API_VERSION),
);
our @EXPORT_OK = ( @EXPORT, 'element' );

# create constructor functions
foreach my $name ( keys %ELEMENTS ) {
    no strict 'refs';    ## no critic

    my ( $parent, @accessors ) = @{ $ELEMENTS{$name} };
    my $numargs = scalar @accessors;
    my $class   = "Pandoc::Document::$name";
    my @parents = map { "Pandoc::Document::$_" } ($parent);
    $parent = join ' ', map { "Pandoc::Document::$_" } $parent,
      map { 'AttributesRole' } grep { $_ eq 'attr' } @accessors;

    eval "package $class; our \@ISA = qw($parent);";

    *{ __PACKAGE__ . "::$name" } = Scalar::Util::set_prototype(
        sub {
            croak "$name expects $numargs arguments, but given " . scalar @_
              if @_ != $numargs;
            my $self = bless { t => $name, c => ( @_ == 1 ? $_[0] : [@_] ) }, $class;
            $self->set_content(@_);
            $self;
        },
        '$' x $numargs
    );

    for ( my $i = 0 ; $i < @accessors ; $i++ ) {
        my $member = @accessors == 1 ? "\$e->{c}" : "\$e->{c}->[$i]";
        my $code = "my \$e = shift; $member = ( 1 == \@_ ? \$_[0] : [\@_] ) if \@_; return";
        # auto-bless on access via accessor (TODO: move to constructor?)
        $code .= $accessors[$i] =~ s/:\[(.+)\]$//
        ? " [ map { bless \$_, 'Pandoc::Document::$1' } \@{$member} ];"
        : " $member;";
        for ( split '/', $accessors[$i] ) {
            *{ $class . "::$_" } = eval "sub { $code }";
        }
    }
}

sub element {
    my $name = shift;
    no strict 'refs';
    croak "undefined element" unless defined $name;
    croak "unknown element $name" unless $ELEMENTS{$name};
    &$name(@_);
}

sub Document {

    # input interpreted differently based on number of arguments

    # TODO: deprecate all but AST REPRESENTATION and MIXED STYLE?

    # 1 argument: AST REPRESENTATION
    #
    # hashref = NEW STYLE (1.18):
    #     {
    #         meta => \%meta,
    #         blocks => \@content,
    #         'pandoc-api-version'|api_version => (\@array|$api_version_num)
    #         | api_version_of => $exe_version_num
    #     }
    #
    # or arrayref = OLD-STYLE:
    #     [ { unMeta => \%meta }, \@blocks ]

    my $arg = ( 1 == @_ ) ? shift

      # 2 arguments: OLD STYLE: \%meta, \@blocks
      : ( 2 == @_ ) ? { meta => $_[0], blocks => $_[1], api_version => 0 }

      # 3 arguments: EXTENDED OLD STYLE for easy upgrade: \%meta, \@blocks, $api_version
      : ( 3 == @_ ) ? { meta => $_[0], blocks => $_[1], api_version => $_[2] }

      # elsif odd number of args: ERROR
      : ( @_ % 2 ) ? croak( "Document: too many or ambiguous arguments" )

      # elsif even number of args:
      # MIXED STYLE prepared for future extensions: \%meta, \@blocks, %params
      : { meta => shift, blocks => shift, @_ };

    # old-style AST representation
    if ( 'ARRAY' eq reftype $arg ) {
        $arg = { meta => $arg->[0]->{unMeta}, blocks => $arg->[1] };
    }

    'HASH' eq reftype $arg
      or croak
      'Usage: Document({blocks => \@blocks, meta => \%meta, api_version => $api_version})';

    my $api_version =

      # prefer haskell-style key but accept perl-style key
      $arg->{'pandoc-api-version'} // $arg->{pandoc_api_version}

      # accept abbreviated key
      // $arg->{api_version}

      # Fall back on pkg var // env var // undef (undef for old-style JSON)
      // $PANDOC_API_VERSION // undef;

    # XXX: undef API version == pre-pandoc-1.18; also signals
    # * Pandoc::Document::TO_JSON to emit old-style AST
    # * Pandoc::Document::LineBlock::TO_JSON to downgrade representation

    # We copy values here because $arg may not be a pure AST representation
    return bless {
        meta   => metadata( $arg->{meta} // {} ),
        blocks => ( $arg->{blocks}       // [] ),
        'pandoc-api-version' =>    # undef for old-style JSON
                                   # XXX: usage must take care with undef value!
          ( defined( $api_version ) ? Pandoc::Version->new( $api_version ) : undef ),
      },
      'Pandoc::Document';
}

sub pandoc_version    { Pandoc::Version->new( @_ ) }
sub pandoc_api_version_of {
    my $exe_version = Pandoc::Version->new($_[0]);
    return $PANDOC_API_VERSION_OF{ $exe_version } // return; # undef for out-of-range version

    # my $api_version
    #   = $exe_version lt '1.12' ? croak( "Versions of pandoc before 1.12 are not supported by Pandoc::Elements" )
    #   : $exe_version >= '1.12' and $exe_version < '1.18' ? 0
    #   : $PANDOC_API_VERSION_OF{ $exe_version } // croak "Version $exe_version of pandoc is not supported by this version of Pandoc::Elements";
    # return Pandoc::Version->new( $api_version );
}

sub pandoc_exe_version_of {
    my ( $api_version, $get_all ) = @_;
    $api_version = Pandoc::Version->new( $api_version // return );

    # my $exe_version = $api_version < '1.17.0.4'
    #   ? do {
    #     carp
    #       "pandoc_exe_version_of: andoc API versions before 1.17.0.4 (pandoc 1.18) are not detected. Returning undef.";
    #     return;
    #   }
    #   : $PANDOC_EXE_VERSION_OF->{$api_version} // croak
    #   "Pandoc API version $api_version is not supported by Pandoc::Elements";

    my $exe_version = $PANDOC_EXE_VERSION_OF->{$api_version} // return # undef/empty list for out-of-range-version
    if ( $get_all ) {
      ## return an arrayref with all executable versions which used this API version
        return [ map { Pandoc::Version->new( $_ ) }
              $PANDOC_EXE_VERSION_OF->get_all( $api_version ) ];
    }
  ## return the last executable version which used this API version
    return Pandoc::Version->new( $exe_version );
}

# specific accessors

sub Pandoc::Document::DefinitionPair::term        { $_[0]->[0] }
sub Pandoc::Document::DefinitionPair::definitions { $_[0]->[1] }

# additional functions

sub attributes($) {

    my $e = Span(['',[],[]],[]); # to make use of AttributesRole
    $e->keyvals(@_);

    return $e->attr;
}

sub citation($) {
    my $a = shift;
    {
        citationId     => $a->{id}     // "missing",
        citationPrefix => $a->{prefix} // [],
        citationSuffix => $a->{suffix} // [],
        citationMode   => $a->{mode}   // bless(
            { t => 'NormalCitation', c => [] },
            'Pandoc::Document::NormalCitation'
        ),
        citationNoteNum => $a->{num}  // 0,
        citationHash    => $a->{hash} // 1,
    };
}

sub metadata($) {
    $_[0]; # TODO: issue #10 and #34
}

sub pandoc_json($) {
    state $ast_to_element = sub {   # compile once, use repeatedly, keep private
        my $class = 'Pandoc::Document::' . $_[0]->{t};
        if ( 'MetaMap' eq $_[0]->{t} ) {
            for my $v ( values %{ $_[0]->{c} } ) {
                $_[1]->( $v, $_[1] );
            }
        }
        return $class->new_from_ast( $_[0] );
    };

    shift if $_[0] =~ /^Pandoc::/;

    my $ast = eval { decode_json( $_[0] ) };
    if ($@) {
        $@ =~ s/ at [^ ]+Elements\.pm line \d+//;
        chomp $@;
        croak $@;
    }
    return unless reftype $ast;

    if ( reftype $ast eq 'ARRAY' ) {

        # old style AST representation
        $ast = { meta => $ast->[0]{unMeta}, blocks => $ast->[1], }
        if reftype $ast->[0] eq 'HASH' and exists $ast->[0]{unMeta};
    }

    if ( reftype $ast eq 'HASH' and $ast->{t} ) {

        # A document element

        # $ast = element( $ast->{t}, $ast->{c} );
        $ast = $ast_to_element->( $ast, $ast_to_element );
    }
    elsif ( reftype $ast eq 'HASH' and exists $ast->{blocks} ) {

        # new-style AST representation
        my $meta = $ast->{meta};
        for my $v ( values %$meta ) {
            $v = $ast_to_element->( $v, $ast_to_element );
        }
        $ast = Document( $ast ); # handles new/old format
    }

    walk $ast, $ast_to_element;

    return $ast;
}

*pandoc_query = *Pandoc::Walker::query;

# document element packages

{

    package Pandoc::Document;
    use strict;
    our $VERSION = '0.04';  # TODO: bump this considerably, assuming it should be == Pandoc::Elements version?
    our @ISA = ('Pandoc::Document::Element');
    sub blocks;
    sub name { 'Document' }
    sub meta {
        $_[0]->{meta} = Pandoc::Elements::metadata($_[1]) if @_ > 1;
        $_[0]->{meta};
    }
    sub content {
        $_[0]->{blocks} = $_[1] if @_ > 1;
        $_[0]->{blocks};
    }
    *blocks = \&content;
    sub is_document { 1 }
    sub metavalue {
        my $meta = $_[0]->meta;
        return { map { $_ => $meta->{$_}->metavalue } keys %$meta }
    }
    sub string {
        join '', map { $_->string } @{$_[0]->content}
    }
    sub api_version {
        my $self = shift;
        if ( @_ ) {
            $self->{'pandoc-api-version'}
              = defined( $_[0] )
              ? Pandoc::Version->new( $_[0] )
              : undef    # undef for old-style JSON
        }
        return $self->{'pandoc-api-version'};
    }
    sub new_from_ast { shift;  Pandoc::Elements::Document( @_ ); }
}

{

    package Pandoc::Document::Element;
    use strict;
    use warnings;
    our $VERSION = $Pandoc::Document::VERSION;
    use JSON ();
    use Scalar::Util qw(reftype blessed);
    use Pandoc::Walker ();
    use subs qw(walk query transform);    # Silence syntax warnings

    sub to_json {
        JSON->new->utf8->canonical->convert_blessed->encode( $_[0] );
    }

    sub TO_JSON {

        # Run everything thru this method so arrays/hashes are cloned
        # and objects without TO_JSON methods are stringified.
        # Required to ensure correct scalar types for Pandoc.

# There is no easy way in Perl to tell if a scalar value is already a string or number,
# so we stringify all scalar values and numify/boolify as needed afterwards.

        my ( $ast, $maybe_blessed ) = @_;
        if ( $maybe_blessed && blessed $ast ) {
            if ( my $TO_JSON = $ast->can('TO_JSON' ) ) {
                # $PANDOC_API_VERSION may be localized so that
                # contained objects get the appropriate representation
                # therefore we call the object's TO_JSON method
                return $TO_JSON->($ast);  # save a method lookup
            }
                 # may have overloaded stringification! Should we check?
                 # require overload;
              # return "$ast" if overload::Method($ast, q/""/) or overload::Method($ast, q/0+/);
              # carp "Non-stringifiable object $ast";
            return "$ast";
        }
        elsif ( 'ARRAY' eq reftype $ast ) {
            return [ map { ref($_) ? TO_JSON( $_, 1 ) : "$_"; } @$ast ];
        }
        elsif ( 'HASH' eq reftype $ast ) {
            my %ret = %$ast;
            while ( my ( $k, $v ) = each %ret ) {
                $ret{$k} = ref($v) ? TO_JSON( $v, 1 ) : "$v";
            }
            return \%ret;
        }
        else { return "$ast" }
    }

    sub name        { $_[0]->{t} }
    sub content     {
       my $e = shift;
       $e->set_content(@_) if @_;
       $e->{c}
    }
    sub set_content { # TODO: document this
       my $e = shift;
       $e->{c} = @_ == 1 ? $_[0] : [@_]
    }
    sub is_document { 0 }
    sub is_block    { 0 }
    sub is_inline   { 0 }
    sub is_meta     { 0 }
    *walk      = *Pandoc::Walker::walk;
    *query     = *Pandoc::Walker::query;
    *transform = *Pandoc::Walker::transform;

    sub new_from_ast { bless $_[1] => $_[0] }

    sub string {

        # TODO: fix issue #4 to avoid this duplication
        if ( $_[0]->name =~ /^(Str|Code|Math|MetaString)$/ ) {
            return $_[0]->content;
        }
        elsif ( $_[0]->name =~ /^(LineBreak|SoftBreak|Space)$/ ) {
            return ' ';
        }
        join '', @{
            $_[0]->query(
                {
                    'Str|Code|Math|MetaString'  => sub { $_->content },
                    'LineBreak|Space|SoftBreak' => sub { ' ' },
                }
            );
        };
    }

    # TODO: replace by new class Pandoc::Selector with compiled code
    sub match {
        my $self = shift;
        foreach my $selector ( split /\|/, shift ) {
            return 1 if $self->match_simple($selector);
        }
        return 0;
    }

    sub match_simple {
        my ( $self, $selector ) = @_;
        $selector =~ s/^\s+|\s+$//g;

        # name
        return 0
          if $selector =~ s/^([a-z]+)\s*//i and lc($1) ne lc( $self->name );
        return 1 if $selector eq '';

        # type
        if ( $selector =~ s/^:(document|block|inline|meta)\s*// ) {
            my $method = "is_$1";
            return 0 unless $self->$method;
            return 1 if $selector eq '';
        }

        # id and/or classes
        return 0 unless $self->can('match_attributes');
        return $self->match_attributes($selector);
    }

}

{

    package Pandoc::Document::AttributesRole;
    use Hash::MultiValue;
    use Scalar::Util qw(reftype blessed);
    use Carp qw(croak);

    my $IDENTIFIER = qr{\p{L}(\p{L}|[0-9_:.-])*};

    sub id {
        $_[0]->attr->[0] = defined $_[1] ? "$_[1]" : "" if @_ > 1;
        $_[0]->attr->[0]
    }

    sub classes {
        my $e = shift;
        croak 'Method classes() is not a setter' if @_;
        warn "->classes is deprecated, use ->class instead\n";
        $e->attr->[1]
    }

    sub class {
        my $e = shift;
        if (@_) {
            $e->attr->[1] = [
                grep { $_ ne '' }
                map { split qr/\s+/, $_ }
                map { (ref $_ and reftype $_ eq 'ARRAY') ? @$_ : $_ }
                @_
            ];
        }
        join ' ', @{$e->attr->[1]}
    }

    sub add_attribute {
        my ($e, $key, $value) = @_;
        if ($key eq 'id') {
            $e->id($value);
        } elsif ($key eq 'class') {
            $value //= '';
            $value = ["$value"] unless (reftype $value // '') eq 'ARRAY';
            push @{$e->attr->[1]}, grep { $_ ne '' } map { split qr/\s+/, $_ } @$value;
        } else {
            push @{$e->attr->[2]}, [ $key, "$value" ];
        }
    }

    sub keyvals {
        my $e = shift;
        if (@_) {
            my $attrs = @_ == 1 ? shift : Hash::MultiValue->new(@_);
            unless (blessed $attrs and $attrs->isa('Hash::MultiValue')) {
                $attrs = Hash::MultiValue->new(%$attrs);
            }
            $e->attr->[1] = [] if exists $attrs->{class};
            $e->attr->[2] = [];
            $attrs->each(sub { $e->add_attribute(@_) });
        }
        my @h;
        push @h, id => $e->id if $e->id ne '';
        push @h, class => $e->class if @{$e->attr->[1]};
        Hash::MultiValue->new( @h, map { @$_ } @{$e->attr->[2]} );
    }

    # TODO: rename and/or extend to keyvals check
    sub match_attributes {
        my ( $self, $selector ) = @_;
        $selector =~ s/^\s+|\s+$//g;

        while ( $selector ne '' ) {
            if ( $selector =~ s/^#($IDENTIFIER)\s*// ) {
                return 0 unless $self->id eq $1;
            }
            elsif ( $selector =~ s/^\.($IDENTIFIER)\s*// ) {
                return 0 unless grep { $1 eq $_ } @{ $self->attr->[1] };
            }
            else {
                return 0;
            }
        }

        return 1;
    }
}

{

    package Pandoc::Document::Block;
    our $VERSION = $PANDOC::Document::VERSION;
    our @ISA     = ('Pandoc::Document::Element');
    sub is_block { 1 }
}

{

    package Pandoc::Document::Inline;
    our $VERSION = $PANDOC::Document::VERSION;
    our @ISA     = ('Pandoc::Document::Element');
    sub is_inline { 1 }
}

{

    package Pandoc::Document::Meta;
    use Scalar::Util 'reftype';
    our $VERSION = $PANDOC::Document::VERSION;
    our @ISA     = ('Pandoc::Document::Element');
    sub is_meta { 1 }
}

{

    package Pandoc::Document::LinkageRole;
    our $VERSION = $PANDOC::Document::VERSION;

    for my $Element (qw[ Link Image ]) {
        no strict 'refs';    #no critic
        unshift @{"Pandoc::Document::${Element}::ISA"}, __PACKAGE__; # no critic
    }

    sub url   { $_[0]->{c}->[-1][0] }
    sub title { $_[0]->{c}->[-1][1] }

    sub new_from_ast {
        my ( $class, $ast ) = @_;
        if ( 2 == @{ $ast->{c} } ) {

            # prepend attributes to old-style ast
            unshift @{ $ast->{c} }, [ "", [], [] ];
        }
        return bless $ast => $class;
    }
}

# Special TO_JSON methods to coerce data to int/number/Boolean as appropriate
# and to downgrade document model for older versions of pandoc

sub Pandoc::Document::TO_JSON {
    # fatal uninitialized warning so eval catches it
    # eval because ->api_version value may be undef instead of object!
    use warnings FATAL => 'uninitialized';
    my ( $self ) = @_;
    local $PANDOC_API_VERSION = eval { $self->api_version->string };
    return Pandoc::Document::Element::TO_JSON(
        eval { $self->api_version ge '1.17.0.4' }
        ? $self
        : [ { unMeta => $self->{meta} }, $self->{blocks} ]
    );
}

sub Pandoc::Document::LineBlock::TO_JSON {
    my $ast     = Pandoc::Document::Element::TO_JSON( $_[0] );
    my $content = $ast->{c};
    for my $line ( @$content ) {

        # Convert spaces at the beginning of each line
        # to Unicode non-breaking spaces, because pandoc does.
        next unless $line->[0]->{t} eq 'Str';
        $line->[0]->{c} =~ s{^(\x{20}+)}{ "\x{a0}" x length($1) }e;
    }
    if ( defined $PANDOC_API_VERSION ) {
        return $ast if $PANDOC_API_VERSION ge '1.17.0.4';
        my $c = [ map { ; @$_, LineBreak() } @{$content} ];
        pop @$c;    # remove trailing line break
        return Para( $c )->TO_JSON;
    }
    else {
        return $ast;
    }
}

sub Pandoc::Document::SoftBreak::TO_JSON {
    if ( $Pandoc::Elements::PANDOC_VERSION
        and ( $Pandoc::Elements::PANDOC_VERSION lt '1.16' ) ) {
        return { t => 'Space', c => [] };
    } else {
        return { t => 'SoftBreak', c => [] };
    }
}

sub Pandoc::Document::LinkageRole::TO_JSON {
    my $ast = Pandoc::Document::Element::TO_JSON( $_[0] );
    if ( $Pandoc::Elements::PANDOC_VERSION
        and ( $Pandoc::Elements::PANDOC_VERSION lt '1.16' ) )
    {
        # remove attributes from new-style ast
        $ast->{c} = [ @{ $ast->{c} }[ 1, 2 ] ];
    }
    return $ast;
}

sub Pandoc::Document::Header::TO_JSON {
    my $ast = Pandoc::Document::Element::TO_JSON( $_[0] );

    # coerce heading level to int
    $ast->{c}[0] = int( $ast->{c}[0] );
    return $ast;
}

sub Pandoc::Document::OrderedList::TO_JSON {
    my $ast = Pandoc::Document::Element::TO_JSON( $_[0] );

    # coerce first item number to int
    $ast->{c}[0][0] = int( $ast->{c}[0][0] );
    return $ast;
}

sub Pandoc::Document::Table::TO_JSON {
    my $ast = Pandoc::Document::Element::TO_JSON( $_[0] );

    # coerce column widths to numbers (floats)
    $_ += 0 for @{ $ast->{c}[2] };    # faster than map
    return $ast;
}

sub Pandoc::Document::MetaBool::set_content {
    $_[0]->{c} = $_[1] && $_[1] ne 'false' && $_[1] ne 'FALSE'
}

sub Pandoc::Document::MetaBool::TO_JSON {
    return {
        t => 'MetaBool',

        # coerce Bool value to JSON Boolean object
        c => $_[0]->{c} ? JSON::true() : JSON::false(),
    };
}

sub Pandoc::Document::MetaBool::metavalue {
    $_[0]->{c} ? 1 : 0
}

sub Pandoc::Document::MetaMap::metavalue {
    my $map = $_[0]->{c};
    return { map { $_ => $map->{$_}->metavalue } keys %$map }
}

sub Pandoc::Document::MetaInlines::metavalue {
    join '', map { $_->string } @{$_[0]->{c}}
}

sub Pandoc::Document::MetaBlocks::metavalue {
    join "\n", map { $_->string } @{$_[0]}->{c}
}

sub Pandoc::Document::MetaList::metavalue {
    [ map { $_->metavalue } @{$_[0]->{c}} ]
}

sub Pandoc::Document::MetaString::metavalue {
    $_[0]->{c}
}

sub Pandoc::Document::Cite::TO_JSON {
    my $ast = Pandoc::Document::Element::TO_JSON( $_[0] );
    for my $citation ( @{ $ast->{c}[0] } ) {
        for my $key (qw[ citationHash citationNoteNum ]) {

            # coerce to int
            $citation->{$key} = int( $citation->{$key} );
        }
    }
    return $ast;
}

1;
__END__

=encoding utf-8

=head1 NAME

Pandoc::Elements - create and process Pandoc documents

=begin markdown

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Pandoc-Elements.svg)](https://travis-ci.org/nichtich/Pandoc-Elements)
[![Coverage Status](https://coveralls.io/repos/nichtich/Pandoc-Elements/badge.svg)](https://coveralls.io/r/nichtich/Pandoc-Elements)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/Pandoc-Elements.png)](http://cpants.cpanauthors.org/dist/Pandoc-Elements)

=end markdown

=head1 SYNOPSIS

The output of this script C<hello.pl>

    use Pandoc::Elements;
    use JSON;

    print Document({
            title => MetaInlines [ Str "Greeting" ]
        }, [
            Header( 1, attributes { id => 'top' }, [ Str 'Hello' ] ),
            Para [ Str 'Hello, world!' ],
        ])->to_json;

can be converted for instance to HTML with via

    ./hello.pl | pandoc -f json -t html5 --standalone

an equivalent Pandoc Markdown document would be

    % Greeting
    # Gruß {.de}
    Hello, world!

=head1 DESCRIPTION

Pandoc::Elements provides utility functions to create abstract syntax trees
(AST) of L<Pandoc|http://pandoc.org/> documents. Pandoc can convert the
resulting data structure to many other document formats, such as HTML, LaTeX,
ODT, and ePUB.

Please make sure to use at least Pandoc 1.12 when processing documents

See also module L<Pandoc::Filter>, command line script L<pod2pandoc>, and the
internal modules L<Pandoc::Walker> and L<Pod::Simple::Pandoc>.

=head1 FUNCTIONS

The following functions and keywords are exported by default:

=over

=item

Constructors for all Pandoc document element (L<block elements|/BLOCK ELEMENTS>
such as C<Para> and L<inline elements|/INLINE ELEMENTS> such as C<Emph>,
L<metadata elements|/METADATA ELEMENTS> and the L<Document|/DOCUMENT ELEMENT>).

=item

L<Type keywords|/TYPE KEYWORDS> such as C<Decimal> and C<LowerAlpha> to be used
as types in other document elements.

=item

The helper following functions C<pandoc_json>, C<attributes>, C<citation>, and
C<element>.

=back

=head2 pandoc_json $json

Parse a JSON string, as emitted by pandoc in JSON format. This is the reverse
to method C<to_json> but it can read both old (before Pandoc 1.16) and new
format.

=head2 attributes { key => $value, ... }

Maps a hash reference or instance of L<Hash::MultiValue> into the internal
structure of Pandoc attributes. The special keys C<id> (string), and C<class>
(string or array reference with space-separated class names) are recognized.
See L<attribute methods|/ATTRIBUTE METHODS> for details.

=head2 citation { ... }

A citation as part of document element L<Cite|/Cite> must be a hash reference
with fields C<citationID> (string), C<citationPrefix> (list of L<inline
elements|/INLINE ELEMENTS>) C<citationSuffix> (list of L<inline
elements|/INLINE ELEMENTS>), C<citationMode> (one of C<NormalCitation>,
C<AuthorInText>, C<SuppressAuthor>), C<citationNoteNum> (integer), and
C<citationHash> (integer). The helper method C<citation> can be used to
construct such hash by filling in default values and using shorter field names
(C<id>, C<prefix>, C<suffix>, C<mode>, C<note>, and C<hash>):

    citation {
        id => 'foo',
        prefix => [ Str "see" ],
        suffix => [ Str "p.", Space, Str "42" ]
    }

    # in Pandoc Markdown

    [see @foo p. 42]

=head2 element( $name => $content )

Create a Pandoc document element of arbitrary name. This function is only
exported on request.

=head1 ELEMENTS AND METHODS

Document elements are encoded as Perl data structures equivalent to the JSON
structure, emitted with pandoc output format C<json>. All elements are blessed
objects that provide L<common element methods|/COMMON METHODS> (all elements),
L<attribute methods|/ATTRIBUTE METHODS> (elements with attributes), and
additional element-specific methods.

=head2 COMMON METHODS

=head3 to_json

Return the element as JSON encoded string. The following are equivalent:

    $element->to_json;
    JSON->new->utf8->canonical->convert_blessed->encode($element);

Note that the JSON format changed from Pandoc 1.15 to Pandoc 1.16 by introduction
of attributes to L<Link|/Link> and L<Image|/Image> elements. Since Pandoc::Elements
0.16 the new format is serialized by default. Set the package variable or
environment variable C<PANDOC_VERSION> to 1.15 or below to use the old format.

=head3 name

Return the name of the element, e.g. "Para" for a L<paragraph element|/Para>.

=head3 content

Return the element content. For most elements (L<Para|/Para>, L<Emph|/Emph>,
L<Str|/Str>...) the content is an array reference with child elements. Other
elements consist of multiple parts; for instance the L<Link|/Link> element has
attributes (C<attr>, C<id>, C<class>, C<classes>, C<keyvals>) a link text
(C<content>) and a link target (C<target>) with C<url> and C<title>.

=head3 is_block

True if the element is a L<Block element|/BLOCK ELEMENTS>

=head3 is_inline

True if the element is an inline L<Inline element|/INLINE ELEMENTS>

=head3 is_meta

True if the element is a L<Metadata element|/METADATA ELEMENTS>

=head3 is_document

True if the element is a L<Document element|/DOCUMENT ELEMENT>

=head3 walk(...)

Walk the element tree with L<Pandoc::Walker>

=head3 query(...)

Query the element to extract results with L<Pandoc::Walker>

=head3 transform(...)

Transform the element tree with L<Pandoc::Walker>

=head3 string

Returns a concatenated string of element content, leaving out all formatting.

=head2 ATTRIBUTE METHODS

Some elements have attributes which can be an identifier, ordered class names
and ordered key-value pairs. Elements with attributes provide the following
methods:

=head3 attr

Get or set the attributes in Pandoc internal structure:

  [ $id, [ @classes ], [ [ key => $value ], ... ] ]

See helper function L<attributes|/attributes-key-value> to create this
structure.

=head3 keyvals

Get all attributes (id, class, and key-value pairs) as new L<Hash::MultiValue>
instance, or replace I<all> key-value pairs plus id and/or class if these are
included as field names. All class fields are split by whitespaces.

  $e->keyvals                           # return new Hash::MultiValue
  $e->keyvals( $HashMultiValue )        # update by instance of Hash::MultiValue
  $e->keyvals( key => $value, ... )     # update by list of key-value pairs
  $e->keyvals( \%hash )                 # update by hash reference
  $e->keyvals( { } )                    # remove all key-value pairs
  $e->keyvals( id => '', class => '' )  # remove all key-value pairs, id, and class

=head3 id

Get or set the identifier. See also L<Pandoc::Filter::HeaderIdentifiers> for
utility functions to handle L<Header|/Header> identifiers.

=head3 class

Get or set the list of classes, separated by whitespace.

=head3 add_attribute( $name => $value )

Append an attribute. The special attribute names C<id> and C<class> set or
append identifier or class, respectively.

=head2 DOCUMENT ELEMENT

=head3 Document

Root element, consisting of metadata hash (C<meta>) and document element array
(C<content>).

    Document $meta, [ @blocks ]

Document C<metavalue> returns a copy of the metadata hash with all L<metadata
elements|/METADATA ELEMENTS> flattened to unblessed values:

    $doc->metavalue   # equivalent to
    { map { $_ => $doc->meta->{$_}->metavalue } keys %{$doc->meta} }


=head2 BLOCK ELEMENTS

=head3 BlockQuote

Block quote, consisting of a list of L<blocks|/BLOCK ELEMENTS> (C<content>)

    BlockQuote [ @blocks ]

=head3 BulletList

Unnumbered list of items (C<content>=C<items>), each a list of
L<blocks|/BLOCK ELEMENTS>

    BulletList [ [ @blocks ] ]

=head3 CodeBlock

Code block (literal string C<content>) with attributes (C<attr>, C<id>,
C<class>, C<classes>, C<keyvals>)

    CodeBlock $attributes, $content

=head3 DefinitionList

Definition list, consisting of a list of pairs (C<content>=C<items>),
each a term (C<term>, a list of L<inlines|/INLINE ELEMENTS>) and one
or more definitions (C<definitions>, a list of L<blocks|/BLOCK ELEMENTS>).

    DefinitionList [ @definitions ]

    # each item in @definitions being a pair of the form

        [ [ @inlines ], [ @blocks ] ]

=head3 Div

Generic container of L<blocks|/BLOCK ELEMENTS> (C<content>) with attributes
(C<attr>, C<id>, C<class>, C<classes>, C<keyvals>).

    Div $attributes, [ @blocks ]

=head3 Header

Header with C<level> (integer), attributes (C<attr>, C<id>, C<class>,
C<classes>, C<keyvals>), and text (C<content>, a list of L<inlines|/INLINE ELEMENTS>).

    Header $level, $attributes, [ @inlines ]

=head3 HorizontalRule

Horizontal rule

    HorizontalRule

=head3 Null

Nothing

    Null

=head3 OrderedList

Numbered list of items (C<content>=C<items>), each a list of L<blocks|/BLOCK
ELEMENTS>), preceded by list attributes (start number, numbering style, and
delimiter).

    OrderedList [ $start, $style, $delim ], [ [ @blocks ] ]

Supported styles are C<DefaultStyle>, C<Example>, C<Decimal>, C<LowerRoman>,
C<UpperRoman>, C<LowerAlpha>, and C<UpperAlpha>.

Supported delimiters are C<DefaultDelim>, C<Period>, C<OneParen>, and
C<TwoParens>.

=head3 Para

Paragraph, consisting of a list of L<Inline elements|/INLINE ELEMENTS>
(C<content>).

    Para [ $elements ]

=head3 Plain

Plain text, not a paragraph, consisting of a list of L<Inline elements|/INLINE
ELEMENTS> (C<content>).

    Plain [ @inlines ]

=head3 RawBlock

Raw block with C<format> and C<content> string.

    RawBlock $format, $content

=head3 Table

Table, with C<caption>, column C<alignments>, relative column C<widths> (0 =
default), column C<headers> (each a list of L<blocks|/BLOCK ELEMENTS>), and
C<rows> (each a list of lists of L<blocks|/BLOCK ELEMENTS>).

    Table [ @inlines ], [ @alignments ], [ @width ], [ @headers ], [ @rows ]

Possible alignments are C<AlignLeft>, C<AlignRight>, C<AlignCenter>, and
C<AlignDefault>.

An example:

    Table [Str "Example"], [AlignLeft,AlignRight], [0.0,0.0],
     [[Plain [Str "name"]]
     ,[Plain [Str "number"]]],
     [[[Plain [Str "Alice"]]
      ,[Plain [Str "42"]]]
     ,[[Plain [Str "Bob"]]
      ,[Plain [Str "23"]]]];

=head2 INLINE ELEMENTS

=head3 Cite

Citation, a list of C<citations> and a list of L<inlines|/INLINE ELEMENTS>
(C<content>). See helper function L<citation|/citation> to construct
citations.

    Cite [ @citations ], [ @inlines ]

=head3 Code

Inline code, a literal string (C<content>) with attributes (C<attr>, C<id>,
C<class>, C<classes>, C<keyvals>)

    Code attributes { %attr }, $content

=head3 Emph

Emphasized text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Emph [ @inlines ]

=head3 Image

Image with alt text (C<content>, a list of L<inlines|/INLINE ELEMENTS>) and
C<target> (list of C<url> and C<title>) with attributes (C<attr>, C<id>,
C<class>, C<classes>, C<keyvals>).

    Image attributes { %attr }, [ @inlines ], [ $url, $title ]

Serializing the attributes in JSON can be disabled with C<PANDOC_VERSION>.

=head3 LineBreak

Hard line break

    LineBreak

=head3 Link

Hyperlink with link text (C<content>, a list of L<inlines|/INLINE ELEMENTS>)
and C<target> (list of C<url> and C<title>) with attributes (C<attr>, C<id>,
C<class>, C<classes>, C<keyvals>).

    Link attributes { %attr }, [ @inlines ], [ $url, $title ]

Serializing the attributes in JSON can be disabled with C<PANDOC_VERSION>.

=head3 Math

TeX math, given as literal string (C<content>) with C<type> (one of
C<DisplayMath> and C<InlineMath>).

    Math $type, $content

=head3 Note

Footnote or Endnote, a list of L<blocks|/BLOCK ELEMENTS> (C<content>).

    Note [ @blocks ]

=head3 Quoted

Quoted text with quote C<type> (one of C<SingleQuote> and C<DoubleQuote>) and a
list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Quoted $type, [ @inlines ]

=head3 RawInline

Raw inline with C<format> (a string) and C<content> (a string).

    RawInline $format, $content

=head3 SmallCaps

Small caps text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    SmallCaps [ @inlines ]

=head3 SoftBreak

Soft line break

    SoftBreak

Note that the C<SoftBreak> element was added in Pandoc 1.16 to as a matter of
editing convenience to preserve line breaks (as opposed to paragraph breaks)
from input source to output. If you are going to feed a document containing
C<SoftBreak> elements to Pandoc E<lt> 1.16 you will have to set the package
variable or environment variable C<PANDOC_VERSION> to 1.15 or below.

=head3 Space

Inter-word space

    Space

=head3 Span

Generic container of L<inlines|/INLINE ELEMENTS> (C<content>) with attributes
(C<attr>, C<id>, C<class>, C<classes>, C<keyvals>).

    Span attributes { %attr }, [ @inlines ]

=head3 Str

Plain text, a string (C<content>).

    Str $content

=head3 Strikeout

Strikeout text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Strikeout [ @inlines ]

=head3 Strong

Strongly emphasized text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Strong [ @inlines ]

=head3 Subscript

Subscripted text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Supscript [ @inlines ]

=head3 Superscript

Superscripted text, a list of L<inlines|/INLINE ELEMENTS> (C<content>).

    Superscript [ @inlines ]

=head2 METADATA ELEMENTS

Metadata can be provided in YAML syntax or via command line option C<-M>.  All
metadata elements return true for C<is_meta>.  Metadata elements can be
converted to unblessed Perl array references, hash references, and scalars with
method C<metavalue>.  On the document level, metadata (document method C<meta>)
is a hash reference with values being metadata elements. Document method
C<metavalue> returns a flattened copy of this hash.

=head3 MetaString

A plain text string metadata value (C<content>).

    MetaString $content

MetaString values can also be set via pandoc command line client:

    pandoc -M key=$content

=head3 MetaBool

A Boolean metadata value (C<content>). The special values C<"false"> and
C<"FALSE"> are recognized as false in addition to normal false values (C<0>,
C<undef>, C<"">...).

    MetaBool $content

MetaBool values can also be set via pandoc command line client:

    pandoc -M key=true
    pandoc -M key=false

=head3 MetaInlines

Container for a list of L<inlines|/INLINE ELEMENTS> (C<content>) in metadata.

    MetaInlines [ @inlines ]

=head3 MetaBlocks

Container for a list of L<blocks|/BLOCK ELEMENTS> (C<content>) in metadata.

    MetaInlines [ @blocks ]

=head3 MetaList

A list of other L<metadata elements|/METADATA ELEMENTS> (C<content>).

    MetaList [ @values ]

=head3 MetaMap

A map of keys to other metadata elements.

    MetaMap { %map }

=head2 TYPE KEYWORDS

The following document elements are only as used as type keywords in other
document elements:

=over

=item

C<SingleQuote>, C<DoubleQuote>

=item

C<DisplayMath>, C<InlineMath>

=item

C<AuthorInText>, C<SuppressAuthor>, C<NormalCitation>

=item

C<AlignLeft>, C<AlignRight>, C<AlignCenter>, C<AlignDefault>

=item

C<DefaultStyle>, C<Example>, C<Decimal>, C<LowerRoman>, C<UpperRoman>,
C<LowerAlpha>, C<UpperAlpha>

=item

C<DefaultDelim>, C<Period>, C<OneParen>, C<TwoParens>

=back

=head1 SEE ALSO

L<Pandoc> implements a wrapper around the pandoc executable.

L<Text.Pandoc.Definition|https://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Definition.html>
contains the original definition of Pandoc document data structure in Haskell.
This module version was last aligned with pandoc-types-1.16.1.

=head1 AUTHOR

Jakob Voß E<lt>jakob.voss@gbv.deE<gt>

=head1 CONTRIBUTORS

Benct Philip Jonsson E<lt>bpjonsson@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.

=cut
