use strict;
use warnings;
use HTTP::Config;

our $Config = HTTP::Config->new;
$Config->add(m_host => 'www.megaupload.com');
$Config->add(m_host => 'megaupload.com');

sub {
    my ($self, $url) = @_;

    $self->mech->get($url) unless ($self->mech->base || '') eq $url;

    my ($filename) = $self->mech->res->decoded_content =~ m$<font style="font-family:arial; color:#FF6700; font-size:\d+px; font-weight:bold;">(.+)</font><br>$;
    $self->say("filename: $filename");

    my $captcha = [ $self->mech->tree->findnodes('//img[contains(@src, "gencap.php")]') ]->[0];
    my $key = $self->ask('captcha: ' . $captcha->attr('src'));
    
    $self->mech->submit_form(with_fields => { captcha => $key });

    $self->sleep(45); # politely

    my $download_link = [ $self->mech->tree->findnodes(q#id('downloadlink')/a#) ]->[0];
    $self->download($download_link->attr('href'));
};
