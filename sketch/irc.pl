use strict;
use warnings;
use lib 'lib';
use Warg::IRC::Client;
use Warg::Downloader::Interface::IRC;
use Warg::Manager;

$Warg::Role::Log::DefaultLogLevel = 'debug';

my $irc_client = Warg::IRC::Client->new_with_options;
my $manager    = Warg::Manager->new(
    interface => Warg::Downloader::Interface::IRC->new(client => $irc_client),
);
$manager->mech->show_progress(1);

$manager->start_interactive;
