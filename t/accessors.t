use strict;
use Test::More;
use Pandoc::Elements;

my $elem = CodeBlock attributes { class => 'perl' }, 'say "Hi";';
is_deeply $elem->attr, $elem->value->[0], 'CodeBlock->attr';
is $elem->content, 'say "Hi";', 'CodeBlock->content';

$elem = Quoted SingleQuote, 'x';
is $elem->type->name, 'SingleQuote', 'Quoted';

# TODO: test OrderedList ListAttributes DefinitionList

done_testing;
