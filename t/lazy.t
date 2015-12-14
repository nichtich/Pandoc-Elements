use strict;
use v5.010;
use Test::More;
use Pandoc::Elements;
use Pandoc::Filter::Lazy;

foreach my $code (
    'sub { return unless $_->name eq "Emph"; return [] }',
    'Emph => sub { [] }'
) {
    my $filter = Pandoc::Filter::Lazy->new($code);
    ok !$filter->error, 'no error';

    my $doc = Document {}, [ Para [ Str "hello", Emph [ Str "world" ] ] ];
    $filter->apply($doc);
    is_deeply $doc, Document({}, [ Para [ Str "hello" ] ]), 'apply';

    is $filter->script, $code;

    is $filter->code, <<CODE, 'code';
use 5.010;
use strict;
use warnings;
use Pandoc::Filter;
use Pandoc::Elements;

Pandoc::Filter->new( $code );
CODE

}

my %lazy = (
    "Emph\t =>sub { [] }"   => 'Emph => sub { [] }',
    "#id => sub { [] }"     => "'#id' => sub { [] }",
    'Code|CodeBlock => say $_->class' =>
        "'Code|CodeBlock' => sub { say \$_->class }",
    ':class => say $_->class' => "':class' => sub { say \$_->class }",
);
while ( my ($got, $expect) = each %lazy ) {
    my $filter = Pandoc::Filter::Lazy->new($got);
    ok !$filter->error;
    is $filter->script, $expect, $got;
}

done_testing;
