use strict;
use warnings;
use lib 'lib';
use Warg::Manager;

my $url = shift or die "usage: $0 url";
my $manager = Warg::Manager->new(downloader_dir => './downloader');

my $downloader = $manager->produce_downloader_from_url($url, log_level => 'debug') or die 'suitable downloder not found';
$downloader->work($url)->join;
