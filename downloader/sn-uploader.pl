# url: */upload.cgi?mode=dl&file=*

use strict;
use warnings;

sub {
    my ($self, $url) = @_;

    my $res = $self->mech->get($url);

    my $comment = $self->mech->tree->findnodes_as_string(q<//table//tr[td[.='COMMENT']]/td[2]/text()>);
    $self->log(info => "COMMENT: $comment");

    my $dlkey = $self->prompt('dlkey');
    $self->mech->submit_form(with_field => { dlkey => $dlkey });

    if (my $meta_refresh = [ $self->mech->tree->findnodes(q<//meta[@http-equiv='Refresh']>) ]->[0]) {
        my $content = $meta_refresh->attr('content');
        if (my ($download_url) = $content =~ /^\d+;URL=(.+)/) {
            $self->start_download($download_url);
        }
    }
};
