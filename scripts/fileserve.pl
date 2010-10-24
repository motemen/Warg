use strict;
use warnings;

use HTTP::Config;

our $Config = HTTP::Config->new;
$Config->add(m_host => 'www.fileserve.com', m_path_prefix => '/file/');

our $reCAPTCHA_publickey = '6LdSvrkSAAAAAOIwNj-IY-Q-p90hQrLinRIpZBPi';

use URI;
use WWW::reCAPTCHA::Client;
use HTTP::Request::Common qw(POST);

# http://209.222.8.217/delivery/c/s/1/z/1/d/www.fileserve.com/ck/d03d43e93c6f86829c33f4959a3b0af5?_=1287855361530

sub {
    my ($self, $url) = @_;

    local $WWW::Mechanize::HAS_ZLIB = 0; # muhaha

    $self->mech->get($url) unless ($self->mech->base || '') eq $url;

    # ???
    my $cklink;
    my $cklink_res = $self->mech->get('http://209.222.8.217/delivery/v/s/1/z/1/d/www.fileserve.com');
    if ($cklink_res->decoded_content =~ /ckLink="(.+?)"/) {
        $cklink = $1;
    }
    $self->mech->back;

    my $recaptcha_short = $self->mech->tree->findvalue(q#id('recaptcha_shortencode_field')/@value#);

    # ???
    $self->mech->post('http://www.fileserve.com/selectCaptchaTimer.php', [ recaptcha_shortencode_field => $recaptcha_short ]);

    my $recaptcha = WWW::reCAPTCHA::Client->new(user_agent => $self->mech->clone, publickey => $reCAPTCHA_publickey);
    my $captcha_image = $recaptcha->get_image_url;

    my $captcha_key = $self->ask("Captcha: $captcha_image");

    my $check_res = $self->mech->post('http://www.fileserve.com/checkReCaptcha.php', [
        recaptcha_challenge_field   => $recaptcha->challenge,
        recaptcha_response_field    => $captcha_key,
        recaptcha_shortencode_field => $recaptcha_short,
    ]);
    $check_res->is_success or die $check_res->as_string;
    $check_res->decoded_content eq 'success' or die 'reCAPTCHA failed';
    $self->mech->back;

    # ???
    if ($cklink) {
        $self->mech->get($cklink);
        $self->mech->back;
    }

    $self->mech->post($url, [ downloadLink => 'wait' ]);
    my ($wait) = $self->mech->res->decoded_content =~ /^(\d+)$/ or warn $self->mech->res->decoded_content;
    $self->sleep($wait || 30);

    $self->mech->post($url, [ downloadLink => 'show' ]);
    $self->sleep(1);

    my $download_res = $self->mech->simple_request(POST $url, [ download => 'normal' ]);
    $download_res->is_redirect or die 'not redirect: ' . $download_res->as_string;
    $self->download($download_res->header('Location'));

};
