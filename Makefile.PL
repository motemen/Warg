use inc::Module::Install;

name 'Warg';
all_from 'lib/Warg.pm';

# requires '';

test_requires 'Test::More';

tests 't/*.t';
# author_tests 'xt';

auto_include;

WriteAll;
