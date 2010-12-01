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
requires 'Regexp::Common';
requires 'String::Random';
requires 'WWW::NicoVideo::Download';
requires 'Config::Pit';

requires 'Any::Moose', '0.13';
requires_any_moose 'X::Getopt';
requires_any_moose 'X::Getopt::Strict';
requires_any_moose 'X::Types::Path::Class';

test_requires 'Test::More';

tests 't/*.t';
# author_tests 'xt';

readme_markdown_from_pod;

auto_include;

WriteAll;
