use inc::Module::Install;

name 'Warg';
all_from 'lib/Warg.pm';

requires 'AnyEvent';
requires 'AnyEvent::IRC::Client';
requires 'Coro';
requires 'Log::Handler';
requires 'WWW::Mechanize';
requires 'HTTP::Config';
requires 'File::Util';
requiers 'Guard';

requires 'Any::Moose';
requires_any_moose 'X::Getopt';
requires_any_moose 'X::Getopt::Strict';

test_requires 'Test::More';

tests 't/*.t';
# author_tests 'xt';

auto_include;

WriteAll;
