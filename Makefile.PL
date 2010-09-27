use inc::Module::Install;

name 'Warg';
all_from 'lib/Warg.pm';

requires 'AnyEvent';
requires 'AnyEvent::IRC::Client';
requires 'Log::Handler';

requires 'Any::Moose';

requires_any_moose 'X::Getopt::Strict';

test_requires 'Test::More';

tests 't/*.t';
# author_tests 'xt';

auto_include;

WriteAll;
