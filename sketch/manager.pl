use strict;
use warnings;
use lib 'lib';
use Warg::Manager;
use Warg::Role::Log;

binmode STDOUT, ':utf8';

$Warg::Role::Log::DefaultLogLevel = 'debug';

my $url = shift or die "usage: $0 url";
my $manager = Warg::Manager->new(downloader_dir => './downloader');

my $downloader = $manager->produce_downloader_from_url($url) or die 'suitable downloader not found';
$downloader->work($url)->on_destroy(sub { exit });
$downloader->interface->show_prompt(0);
$downloader->interface->interact;
