use strict;
use Test::More 0.96;
use Pandoc::Elements;
use Scalar::Util qw[ blessed reftype ];

# MetaBool

my $doc = pandoc_json(<<JSON);
[ { "unMeta": {
      "foo": { "t": "MetaBool", "c": true },
      "bar": { "t": "MetaBool", "c": false }
} }, [] ]
JSON
ok $doc->meta->{foo}->content, 'true';
ok !$doc->meta->{bar}->content, 'false';

foreach (1, '1', 'true', 'TRUE', 42, 'wtf') {
    my $m = MetaBool($_);
    ok $m->content;
    is '{"c":true,"t":"MetaBool"}', $m->to_json, "true: $_";
}    

foreach (0, '', 'false', 'FALSE', undef) {
    my $m = MetaBool($_);
    ok !$m->content;
    is '{"c":false,"t":"MetaBool"}', $m->to_json, "false: $_";
}    

# MetaInlines

my $m = MetaInlines [ Str "foo" ];
is '{"c":[{"c":"foo","t":"Str"}],"t":"MetaInlines"}', $m->to_json, 'MetaInlines';

# Stringify/bless

my $doc = do {
    local (@ARGV, $/) = ('t/documents/meta.json');
    pandoc_json(<>);
};

# note explain $doc->flatten;

is_deeply { map { $_ => $doc->meta->{$_}->flatten } keys %{$doc->meta} },
    $doc->flatten, 'Document->flatten';

done_testing;
