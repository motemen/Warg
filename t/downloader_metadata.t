use strict;
use warnings;
use Test::More;
use t::Warg::MockLWP;

use URI;
use LWP::Simple qw($ua);

use_ok 'Warg::Downloader::Metadata';

subtest 'soundcloud.pl' => sub {
    my $meta = new_ok 'Warg::Downloader::Metadata', [ script => 'downloader/soundcloud.pl' ];
    isa_ok $meta->http_config, 'HTTP::Config';
    ok     $meta->http_config->matching(URI->new('http://soundcloud.com/takuma-hosokawa/darksidenadeko-electro-mix'));
};

subtest 'nicovideo.pl' => sub {
    my $meta = new_ok 'Warg::Downloader::Metadata', [ script => 'downloader/nicovideo.pl' ];
    isa_ok $meta->http_config, 'HTTP::Config';
    ok     $meta->http_config->matching(URI->new('http://www.nicovideo.jp/watch/sm4915305'));
};

subtest 'sn-uploader.pl' => sub {
    my $meta = new_ok 'Warg::Downloader::Metadata', [ script => 'downloader/sn-uploader.pl' ];
    isa_ok $meta->http_config, 'Regexp';
};

done_testing;
