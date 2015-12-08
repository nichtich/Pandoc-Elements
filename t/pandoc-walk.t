use strict;
use Test::More;
use Test::Output;

plan skip_all => 'release test' unless $ENV{RELEASE_TESTING};

if ( (`pandoc -v` // '') !~ /^pandoc (\d+)\.(\d+)/ or ($1 eq '1' and $2 < 12) ) {
    plan skip_all => 'pandoc >= 1.12 required';
}

my $header = 'Header=>sub{say " " x ($_->level-1), $_->string }';
my $link   = 'Link=>sub{say $_->url}';

output_like { system($^X,'script/pandoc-walk') } qr/^Usage:/, qr//, 'usage';

output_is {
    system($^X,'script/pandoc-walk','t/example.tex',$link);
} "http://example.org/\n", "", "Link (perl code)";

output_is {
    system($^X,'script/pandoc-walk','t/example.tex',$header);
} "Section with ÄÖÜ and link\n Subsection with äöü\n", "", "Header (perl code)";

output_is {
    system($^X,'script/pandoc-walk','t/example.tex','t/outline');
} "Section with ÄÖÜ and link\n Subsection with äöü\n", "", "Header (executable)";

output_is {
    system("$^X script/pandoc-walk t/outline < t/example.md");
} "Section with ÄÖÜ and link\n Subsection with äöü\n", "", "Markdown from STDIN";

done_testing;
