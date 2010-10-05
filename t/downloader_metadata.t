use strict;
use warnings;
use Test::More;
use URI;

use_ok 'Warg::Downloader::Metadata';

subtest 'soundcloud.pl' => sub {
    my $meta = new_ok 'Warg::Downloader::Metadata', [ script => 'downloader/soundcloud.pl' ];
    isa_ok $meta->http_config, 'HTTP::Config';
    ok     $meta->http_config->matching(URI->new('http://soundcloud.com/takuma-hosokawa/darksidenadeko-electro-mix'));
};

done_testing;
