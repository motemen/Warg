use strict;
use warnings;
use Test::More;

use_ok 'Warg::Manager';

my $manager = new_ok 'Warg::Manager', [
    downloader_dir => 'downloader'
];

ok not defined $manager->script_metadata->{'downloader/sn-uploader.pl'}->http_config;
isa_ok $manager->script_metadata->{'downloader/btdownloadheadless.pl'}->http_config,
       'HTTP::Config';

done_testing;
