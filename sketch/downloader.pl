use strict;
use warnings;
use lib 'lib';
use Warg::Downloader;

binmode STDOUT, ':utf8';

my $script = shift or die "Usage: $0 script url";
my $url    = shift or die "Usage: $0 script url";

my $downloader = Warg::Downloader->from_script($script, log_level => 'debug');
$downloader->work($url)->join;
