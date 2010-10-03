use strict;
use warnings;
use lib 'lib';
use Warg::CLI;
use Warg::Downloader;
use Warg::Downloader::Interface::IRC;

my $warg = Warg::CLI->new_with_options;
my ($script, $url, $channel) = @{$warg->extra_argv}
    or die "Usage: $0 [warg-options] script url channel";

my $downloader = Warg::Downloader->from_script(
    $script,
    log_level => 'debug',
    interface => Warg::Downloader::Interface::IRC->new(
        client  => $warg->irc,
        channel => $channel,
    ),
);
$warg->irc->reg_cb(
    registered => sub {
        $warg->logger->notice('about to work');
        $warg->sleep(1);
        $downloader->work($url);
    }
);
$warg->run;
