use strict;
use warnings;

use HTTP::Config;

our $Config = HTTP::Config->new;
$Config->add(m_host => 'www.nicovideo.jp', m_path_prefix => '/watch/');
$Config->add(m_host => 'nico.ms');

# from http://gist.github.com/407777

use WWW::NicoVideo::Download;
use Config::Pit;

my $config = pit_get 'nicovideo.jp', require => {
    username => 'email of nicovideo.jp',
    password => 'password of nicovideo.jp',
};

sub {
    my ($self, $url) = @_;

    my ($video_id) = $url =~ m#/([^/]+)$#;

    my $client = WWW::NicoVideo::Download->new(
        email      => $config->{username},
        password   => $config->{password},
        user_agent => $self->mech,
    );

    local $WWW::Mechanize::HAS_ZLIB = 0; # muhaha

    $self->mech->get($url);

    my $title = $self->mech->tree->findvalue('//h1') || '';
    $title =~ s/[^\w_-]/_/g;

    my $media_url = eval { $client->prepare_download($video_id) };
    if (!$media_url) {
        $self->log(error => 'Could not get media URL');
        $self->log(error => $@) if $@;
        return;
    }

    $self->download($media_url, { prefix => "$title.$video_id." });
};
