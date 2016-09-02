use strict;
use Test::More;
use Pandoc::Elements;

my $e = CodeBlock attributes { class => ['perl'], id => 2 }, 'say "Hi";';

is_deeply $e->attr, $e->{c}->[0], 'CodeBlock->attr';
is $e->id, '2', 'AttributeRole->id';
is_deeply $e->classes, ['perl'], 'AttributeRole->classes';
is $e->class, 'perl', 'AttributeRole->class';

is $e->content, 'say "Hi";', 'CodeBlock->content';

$e = Quoted SingleQuote, 'x';
is $e->type->name, 'SingleQuote', 'Quoted';

# TODO: OrderedList with ListAttributes, Table etc.

$e = DefinitionList [
    [ [ Str 'term 1' ], 
        [ [ Para Str 'definition 1' ] ] ],
    [ [ Str 'term 2' ], 
        [ [ Para Str 'definition 2' ],
          [ Para Str 'definition 3' ] ] ],
];
is scalar @{$e->items}, 2, 'DefinitionList->items';
is_deeply $e->items->[0]->term, [ Str 'term 1' ], '...->term';
is_deeply $e->items->[1]->definitions->[1], 
    [ Para Str 'definition 3' ], '...->definitions';

done_testing;
