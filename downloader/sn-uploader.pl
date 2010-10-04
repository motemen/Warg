use strict;
use warnings;

sub {
    my ($self, $url) = @_;

    my $res = $self->mech->get($url);

    my $comment = [ $self->mech->tree->findnodes(q<//table//tr[td[.='COMMENT']]/td[2]/text()>) ]->[0]->string_value;
    $self->say("COMMENT: $comment");

    my $dlkey = $self->ask('dlkey');
    $self->mech->submit_form(with_fields => { dlkey => $dlkey });

    my $base = $res->base;
    $base =~ s</[^/]+$><>;
    if (my $link = $self->mech->find_link(url_abs_regex => qr(^$base/\w+))) {
        $self->download($link->url);
    }
};
