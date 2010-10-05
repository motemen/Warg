use strict;
use warnings;
use Test::More;
use Test::Deep;
use t::Warg::MockLWP;

use Warg::Downloader::Interface::Code;
use URI::Escape qw(uri_unescape);
use Coro;

use_ok 'Warg::Downloader';

sub HTTP::Message::parsed_content {
    my $self = shift;
    return +{ map { $_->[0] => uri_unescape $_->[1] } map { [ split /=/, $_, 2 ] } split /&/, $self->content };
}

my $interface = Warg::Downloader::Interface::Code->new(
    say => sub { shift; note @_ },
    ask => sub { return 'DLKEY' }
);
my $downloader = new_ok 'Warg::Downloader', [
    script    => 'downloader/sn-uploader.pl',
    interface => $interface,
    log_level => 'emerg',
];

$downloader->mech->add_handler(
    request_preprepare => sub { cede },
);

$downloader->work('http://ichigo-up.com/Sn2/up3/ggg/re10061.tif.html');
cede; # start working

cede; # resume working; go GET http://ichigo-up.com/Sn2/up3/ggg/re10061.tif.html
cmp_deeply $downloader->mech->response, methods(
    base => str 'http://ichigo-up.com/Sn2/up3/ggg/re10061.tif.html',
);

cede; # resume working; go POST http://ichigo-up.com/Sn2/up3/upload.cgi
cmp_deeply $downloader->mech->response, methods(
    base    => str 'http://ichigo-up.com/Sn2/up3/upload.cgi',
    request => methods(
        method => 'POST',
        parsed_content => {
            dlkey => 'DLKEY',
            file  => '10061',
            jcode => '漢字',
            mode  => 'dl',
        },
    ),
);

cede; # resume working; go POST http://ichigo-up.com/Sn2/up3/upload.cgi
cmp_deeply $downloader->mech->response, methods(
    base => str 'http://ichigo-up.com/Sn2/up3/ggg/re10061.tif_F3f1W9TZGbWn6Ws6egs4/re10061.tif',
    [ header => 'Content-Type' ]   => 'image/tiff',
    [ header => 'Content-Length' ] => '786572',
);

done_testing;
