use strict;
use Test::More;
use Pandoc::Elements qw(pandoc_json);

# IMPORTANT:
#
# The JSON in the __DATA__ section is deliberately erroneous,
# i.e. pandoc should choke on it unless the appropriate
# TO_JSON methods have done their magic on it!

SKIP: {
    exists $ENV{PANDOC_VERSION} or skip 'pandoc seems to be missing', 2;
    eval { require IPC::Run3 } or skip 'IPC::Run3 not installed', 2;

    my $json_in = do { local $/; <DATA>; };
    my $document = eval { pandoc_json( $json_in ) };
    my $error = $@;
    is $error, "", 'no error reading "bad" JSON';
    isa_ok $document, 'Pandoc::Document';
    my $json = $document->to_json;

    IPC::Run3::run3( [pandoc => -f => 'json', -t => 'markdown'], \$json, \my $stdout, \my $stderr );

    is $stderr, "", 'no errors feeding JSON to pandoc' or note $stderr;
    note $stdout;
}

done_testing;

__DATA__
[{"unMeta":{"MetaBool":{"t":"MetaBool","c":true}}},[{"t":"Header","c":["1",["heading",[],[]],[{"t":"Str","c":"Heading"},{"c":[],"t":"Space"}]]},{"t":"Para","c":[{"c":[[{"citationMode":{"t":"NormalCitation","c":[]},"citationPrefix":[{"c":"citation","t":"Str"}],"citationSuffix":[{"c":[],"t":"Space"},{"c":"p.","t":"Str"},{"c":[],"t":"Space"},{"c":13,"t":"Str"}],"citationId":"author2015","citationNoteNum":"0","citationHash":"0"}],[{"t":"Str","c":"[citation"},{"t":"Space","c":[]},{"c":"@author2015","t":"Str"},{"t":"Space","c":[]},{"c":"p.","t":"Str"},{"c":[],"t":"Space"},{"c":"13]","t":"Str"}]],"t":"Cite"},{"c":",","t":"Str"},{"c":[],"t":"Space"}]},{"t":"OrderedList","c":[["2",{"t":"Decimal","c":[]},{"t":"OneParen","c":[]}],[[{"t":"Plain","c":[{"c":"#1=2","t":"Str"},{"t":"Space","c":[]}]}],[{"c":[{"t":"Str","c":"#2=3"}],"t":"Plain"}]]]},{"t":"Table","c":[[{"t":"Str","c":"Table"},{"t":"Space","c":[]}],[{"t":"AlignLeft","c":[]},{"t":"AlignLeft","c":[]},{"t":"AlignLeft","c":[]}],["0","0","0"],[[{"t":"Plain","c":[{"t":"Str","c":"M."}]}],[{"t":"Plain","c":[{"t":"Str","c":"F."}]}],[{"c":[{"t":"Str","c":"N."}],"t":"Plain"}]],[[[{"c":[{"t":"Str","c":"hic"}],"t":"Plain"}],[{"c":[{"c":"haec","t":"Str"}],"t":"Plain"}],[{"c":[{"c":"hoc","t":"Str"}],"t":"Plain"}]]]]}]]

