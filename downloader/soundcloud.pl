use strict;
use warnings;

use HTTP::Config;

our $Config = HTTP::Config->new;
$Config->add(m_host => 'soundcloud.com', m_path_match => qr(^/[^/]+/[^/]+$));

sub {
    my ($self, $url) = @_;

    $self->mech->get($url);

    my ($media_url) = $self->mech->response->decoded_content =~ /"streamUrl":"([^"]+)"/
        or do {
            $self->log(error => 'colud not find stream URL');
            warn $self->mech->response->as_string;
            return;
        };

    my ($title) = $self->mech->response->decoded_content =~ m#<h1>(.+?)</h1>#s;
    $title =~ s#<.+?>##g;
    $title =~ s#[\n\r]+##g;
    $self->log(info => "title: $title");

    $self->download($media_url, { prefix => "$title." });
};
