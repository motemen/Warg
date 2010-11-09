use strict;
use warnings;

use HTTP::Config;

our $Config = HTTP::Config->new;
$Config->add(m_host => 'hotfile.com', m_path_prefix => '/dl/');

use WWW::reCAPTCHA::Client;

sub {
    my ($self, $url) = @_;

    $self->mech->get($url) unless ($self->mech->base || '') eq $url;

    if ($self->mech->content =~ m#<script language=JavaScript>starthtimer\(\)</script>#) {
        $self->mech->log(error => 'Reached hourly traffic limit');
        return;
    }

    $self->mech->form_name('f');
    $self->sleep((int($self->mech->current_form->value('wait')) || 30) + 3);
    $self->mech->submit_form;

    if ($self->mech->content =~ /captcha/) {
        my $recaptcha = WWW::reCAPTCHA::Client->new(
            user_agent => $self->mech->clone,
            publickey  => '6LfRJwkAAAAAAGmA3mAiAcAsRsWvfkBijaZWEvkD',
        );
        my $captcha_image = $recaptcha->get_image_url;
        my $captcha_key = $self->ask("Captcha: $captcha_image");

        $self->mech->submit_form(
            with_fields => {
                recaptcha_challenge_field => $recaptcha->challenge,
                recaptcha_response_field  => $captcha_key,
            },
        );
    }

    my $link = $self->mech->find_link(url_regex => qr(/get/))
        or do {
            $self->log(error => 'Could not find link');
            return;
        };

    $self->download($link->url);
};
