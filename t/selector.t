use strict;
use Test::More;
use Pandoc::Elements;
use Pandoc::Selector;

# test matching on elements
my $str = Str('');

ok $str->match('Str'), 'match name';
ok !$str->match('Para'), 'no match';

ok $str->match('str'), 'case-insensitive';

ok $str->match(':inline'), 'type match';
ok !$str->match(':block'), 'type not match';
ok !$str->match(':block'), 'type not match';

ok $str->match('str:inline'), 'multiple match';
ok $str->match('Foo|Str'), '| match';

ok !$str->match(Pandoc::Selector->new('#id')), 'no id match';

{
    my $img = Image attributes {}, [], [ 'http://example.png', '' ];
    ok !$img->match(':title|:attr|:caption'), '!Image[:attr|:title|:caption]';

    $img->title('0');
    $img->id('0');
    $img->caption([Str '0']);
    ok $img->match(':title'), 'Image:title';
    ok $img->match(':attr'), 'Image:attr';
    ok $img->match(':caption'), 'Image:caption';

    my $table = Table [], [AlignLeft], [0.0], [], [ [Plain [Str 'x']] ];
    ok !$table->match(':title|:attr|:caption'), '!Table[:attr|:title|:caption]';
    $table->caption([Str '0']);
    ok $img->match(':caption'), 'Table:caption';
}

my $code = Code attributes { id => 'abc', class => ['f0_0','bar']} , '';

# test matching with selector
ok(Pandoc::Selector->new('#abc')->match($code), 'id match');
ok(!Pandoc::Selector->new('#xyz')->match($code), 'id no match');
ok(!Pandoc::Selector->new('#1')->match($code), 'id no match');

ok(Pandoc::Selector->new('.f0_0')->match($code), 'class match');
ok(Pandoc::Selector->new('.bar .f0_0')->match($code), 'classes match');
ok(!Pandoc::Selector->new('.xyz')->match($code), 'class no match');

ok $code->match("code\t:inline .bar#abc  .f0_0"), 'multiple match';

{
    my $plain = Plain [ Math InlineMath, 'x' ];
    is_deeply $plain->query(':inline'), $plain->content,
        ':inline match without keywords';
}

done_testing;
