use strict;
use Test::More;
use Pandoc::Elements;
use Pandoc;
use Pod::Simple::Pandoc;
use Pod::Simple::Pandoc::Modules;
use Test::Exception;

my $file = 'lib/Pod/Simple/Pandoc.pm';
my $parser = Pod::Simple::Pandoc->new;

my $modules = { 
    'Pod::Simple::Pandoc' => $parser->parse_file($file) 
};
bless $modules, 'Pod::Simple::Pandoc::Modules';

is $modules->index->to_markdown,
   "[Pod::Simple::Pandoc](Pod/Simple/Pandoc.html \"Pod::Simple::Pandoc\")\n",
   'index';

is $modules->index( wiki => 1 )->to_markdown,
   "[Pod::Simple::Pandoc](Pod-Simple-Pandoc \"wikilink\")\n",
   'wiki index';

done_testing;
