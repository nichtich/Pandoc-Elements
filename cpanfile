requires 'perl', '5.010';

# core modules
requires 'Pod::Simple', '3.08';
requires 'List::Util';
requires 'Scalar::Util';
requires 'Pod::Usage';

requires 'JSON';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Output';
};
