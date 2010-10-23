use strict;
use warnings;
use lib 'lib';
use Warg::Downloader;
use Warg::Role::Log;

binmode STDOUT, ':utf8';

my $script = shift or die "Usage: $0 script url";
my $url    = shift or die "Usage: $0 script url";

$Warg::Role::Log::DefaultLogLevel = 'debug';

my $downloader = Warg::Downloader->from_script($script);
$downloader->work($url)->on_destroy(sub { exit });
$downloader->interface->interact;
