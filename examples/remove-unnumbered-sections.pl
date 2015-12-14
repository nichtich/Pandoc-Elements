#!/usr/bin/env perl
use strict;

=head1 DESCRIPTION

Pandoc filter to remove all unnumbered sections.

=cut

use Pandoc::Filter;

my $skip;
pandoc_filter sub {
    if ($skip) {
        if ($_->name eq 'Header' and $_->level <= $skip) {
            $skip = 0;
        } else {
            return [];
        }
    }

    if ($_->name eq 'Header' and $_->match('.unnumbered')) {
        $skip = $_->level;
        return [];
    }
    
    return # keep
};
