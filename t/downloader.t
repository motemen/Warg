use strict;
use warnings;
use Test::More;
use Test::Deep;
use t::Warg::MockLWP;

use Warg::Interface::Code;
use Warg::Manager;

use URI::Escape qw(uri_unescape);
use Coro;
use File::Temp qw(tempdir);
use File::Spec;

my $download_dir = tempdir(CLEANUP => 1);

use_ok 'Warg::Downloader';

subtest progress => sub {
    my $downloader = new_ok 'Warg::Downloader', [ code => sub {} ];
    $downloader->bytes_total(1000);
    $downloader->bytes_received(500);
    is $downloader->progress, 0.5;
};

sub HTTP::Message::parsed_content {
    my $self = shift;
    return +{ map { $_->[0] => uri_unescape $_->[1] } map { [ split /=/, $_, 2 ] } split /&/, $self->content };
}

my $mech = Warg::Mech->new;
$mech->add_handler(
    request_preprepare => sub { cede },
);

subtest 'ichigo-up' => sub {
    my $interface = Warg::Interface::Code->new(
        say => sub { shift; note @_ },
        ask => sub { shift; note @_; return 'DLKEY' }
    );

    my $downloader = Warg::Downloader->from_script(
        'scripts/sn-uploader.pl', (
            interface    => $interface,
            log_level    => 'emerg',
            mech         => $mech,
            download_dir => $download_dir,
        )
    );
    isa_ok $downloader, 'Warg::Downloader';

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
    is $downloader->mech->response->request->uri, 'http://ichigo-up.com/Sn2/up3/ggg/re10061.tif_F3f1W9TZGbWn6Ws6egs4/re10061.tif';

    my $file = File::Spec->catfile($download_dir, 're10061.tif');
    ok -f $file, "stored to $file";
};

done_testing;
