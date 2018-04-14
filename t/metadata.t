use strict;
use Test::More 0.96;
use Pandoc::Elements;
use Scalar::Util qw[ blessed reftype ];

my $doc = pandoc_json(<<JSON);
[ { "unMeta": {
      "true": { "t": "MetaBool", "c": true },
      "false": { "t": "MetaBool", "c": false },
      "string": { "t": "MetaString", "c": "hello\\nworld" },
      "blocks": { "t": "MetaBlocks", "c": [
          {"t": "Para", "c": [{"t":"Str","c":"x"}]},
          {"t": "Para", "c": [{"t":"Str","c":"y"}]}
      ] },
      "map": { "t": "MetaMap", "c": {
        "string": { "t": "MetaString", "c": "0" },
        "list": { "t": "MetaList", "c": [
            { "t": "MetaString", "c": "a" },
            { "t": "MetaString", "c": "b" },
            { "t": "MetaBool", "c": false }
        ] }
      } }
} }, [] ]
JSON

# MetaBool

ok $doc->meta->{true}->content, 'true';
ok !$doc->meta->{false}->content, 'false';

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

# MetaString

is $doc->meta->{string}->content, "hello\nworld";
is $doc->meta->{string}->value, "hello\nworld";

# MetaInlines
{
    my $m = MetaInlines [ Str "foo" ];
    is '{"c":[{"c":"foo","t":"Str"}],"t":"MetaInlines"}',
        $m->to_json, 'MetaInlines';
}

# [meta]value

is_deeply $doc->value, {
    false => 0,
    true => 1,
    string => "hello\nworld",
    blocks => [ "x", "y" ],
    map => {
        string => "0",
        list => ["a", "b", 0]
    }
  }, 'value';

is $doc->value('false'), 0, 'value("false")';
is $doc->value('true'), 1, 'value("true")';
is $doc->value('map.string'), "0", 'value("map.string")';
is $doc->value('map.xxx'), undef, 'value("map.xxx")';
is $doc->value('xxx'), undef, 'value("xxx")';

my $doc = do {
    local (@ARGV, $/) = ('t/documents/meta.json');
    pandoc_json(<>);
};

is_deeply { map { $_ => $doc->metavalue($_) } keys %{$doc->meta} },
    $doc->metavalue, 'Document->metavalue';

done_testing;
