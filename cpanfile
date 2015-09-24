requires 'perl', '5.010';
requires 'JSON';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Output';
};
