use inc::Module::Install;

name 'Warg';
all_from 'lib/Warg.pm';

requires 'AnyEvent';
requires 'AnyEvent::IRC::Client';
requires 'Coro';
requires 'Log::Handler';
requires 'WWW::Mechanize';
requires 'LWPx::ParanoidAgent';
requires 'HTTP::Config';
requires 'File::Util';
requires 'Guard';
requires 'File::chdir';
requires 'HTML::TreeBuilder::XPath', '0.11';

requires 'Any::Moose', '0.13';
requires_any_moose 'X::Getopt';
requires_any_moose 'X::Getopt::Strict';

test_requires 'Test::More';

tests 't/*.t';
# author_tests 'xt';

readme_markdown_from_pod;

auto_include;

WriteAll;
