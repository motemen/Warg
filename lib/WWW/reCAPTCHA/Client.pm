package WWW::reCAPTCHA::Client;
use Any::Moose;

has user_agent => (
    is  => 'rw',
    default => sub {
        require LWP::UserAgent;
        return  LWP::UserAgent->new;
    },
);

has publickey => (
    is  => 'rw',
    isa => 'Str',
    required => 1,
);

has api_root => (
    is  => 'rw',
    isa => 'Str',
    default => 'http://www.google.com/recaptcha/api',
);

has challenge => (
    is  => 'rw',
    isa => 'Str',
);

no Any::Moose;

use JSON -support_by_pp;

__PACKAGE__->meta->make_immutable;

sub do_challenge {
    my $self = shift;

    my $url = $self->api_root . '/challenge?k=' . $self->publickey;
    my $res = $self->user_agent->get($url);
    $res->is_success or die "GET $url: $res->message";

    $res->decoded_content =~ /^var RecaptchaState = ({.+});$/ms or die 'Could not parse response';

    my $challenge = eval { JSON->new->allow_barekey->allow_singlequote->decode($1) } or die qq(Could not parse JSON: $@, text='$1');
    unless ($challenge->{challenge}) {
        die sprintf 'Could not receive challenge: programming_error: %s, error_message: %s', $challenge->{programming_error}, $challenge->{error_message};
    }

    return $self->challenge($challenge->{challenge});
}

sub get_image_url {
    my $self = shift;
    $self->do_challenge;
    return $self->api_root . '/image?c=' . $self->challenge;
}

1;
