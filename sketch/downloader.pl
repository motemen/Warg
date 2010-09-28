use strict;
use warnings;
use lib 'lib';
use Warg::Downloader;
use Log::Handler;

my $script = shift or die;
my $url    = shift or die;

my $downloader = Warg::Downloader->from_script($script);
$downloader->logger(Log::Handler->new(screen => { maxlevel => 'debug' }));
$downloader->mech->show_progress(1);
$downloader->work($url);

AE::cv->wait;
