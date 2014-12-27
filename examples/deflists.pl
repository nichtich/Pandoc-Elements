#!/usr/bin/env perl
use strict;

=head1 DESCRIPTION

Pandoc filter to convert definition lists to bullet lists with the defined
terms in strong emphasis (for compatibility with standard markdown).

=cut

use Pandoc::Filter qw(pandoc_filter);
use Pandoc::Elements qw(BulletList Para Strong Str);

pandoc_filter sub {
    my $dl = shift;
    return if $dl->name ne 'DefinitionList';
    BulletList [ map { to_bullet($_) } @{$dl->items} ]
};

sub to_bullet {
    my $item = shift;
    [ Para [ Strong $item->term ], map { @$_} @{$item->definitions} ]
}

=head1 SEE ALSO

This is a port of
L<deflists.py|https://github.com/jgm/pandocfilters/blob/master/examples/deflists.py>
from Python to Perl with L<Pandoc::Elements>.

=cut

# awk '(d){print};/__DATA__/{d=1};' examples/deflists.pl | pandoc -t json | perl -Ilib examples/deflists.pl | pandoc -f json -t markdown
__DATA__

term 1
  ~ definition 1

term 2
  ~ definition 2

  ~ definition 3

    following paragraph
