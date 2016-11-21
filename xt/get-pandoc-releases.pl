#!/usr/bin/env perl
use v5.10;
use strict;

use JSON;
use LWP::UserAgent;
use Cwd;
use File::Path qw(make_path remove_tree);

my $UA = LWP::UserAgent->new;
my $dir = getcwd;

chdir 'xt';
make_path('deb');
make_path('bin');

# download all Debian 64bit releases of pandoc
foreach my $r (releases("jgm","pandoc")) {
    my ($asset) = grep { $_->{name} =~ /-amd64\.deb$/ } @{$r->{assets}};
    my $url = $asset->{browser_download_url} or next;
    my $name = $asset->{name};      # could also be parsed from url
    my $version = $r->{tag_name};   # could also be parsed from url or name
    my $file = "deb/$name";

    say $file if $UA->mirror($url, $file)->is_success;
    
    # extract pandoc executable and move it to subdirectory
    make_path("bin/$version");
    remove_tree("usr");
    `dpkg --fsys-tarfile $file | tar -x ./usr/bin/pandoc`;
    `mv ./usr/bin/pandoc bin/$version`
}    

chdir $dir;

# get all releases of a GitHub repository
sub releases {
    my ($user, $repo) = @_;

    my $url = "https://api.github.com/repos/$user/$repo/releases";

    my @releases;

    while ($url) {
        say $url;
        my $res = $UA->get($url);
        $res->is_success or last;
        push @releases, @{ decode_json($res->decoded_content) };

        my $link = $res->header('Link');
        $link =~ /<([^>]+)>; rel="next"/ or last;
        $url = $1;
    }

    return @releases;
}


