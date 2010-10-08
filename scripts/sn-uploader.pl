use strict;
use warnings;

use HTTP::Config;

our $Config = qr</upload\.cgi\?mode=dl&file=\w+$>;

sub {
    my ($self, $url) = @_;

    my $res = $self->mech->get($url);

    my @tr = $self->mech->tree->findnodes(q<//table//tr[td[2]]>);
    $self->say(join ': ', $_->findnodes_as_strings('td/text()')) for @tr;

    my $dlkey = $self->ask('dlkey');
    $self->mech->submit_form(with_fields => { dlkey => $dlkey });

    my $base = $res->base;
    $base =~ s</[^/]+$><>;
    if (my $link = $self->mech->find_link(url_abs_regex => qr(^$base/\w+))) {
        $self->download($link->url);
    }
};
