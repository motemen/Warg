use strict;
use warnings;
use lib 'lib';
use Warg::IRC::Client;
use Warg::Downloader::Interface::Console;
use Warg::Manager;

$Warg::Role::Log::DefaultLogLevel = 'debug';

my $manager = Warg::Manager->new(
    interface => Warg::Downloader::Interface::Console->new,
);

$manager->start_interactive;
