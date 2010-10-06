package Warg::Downloader::Interface::IRC;
use Any::Moose;

with 'Warg::Role::Interface';

has client => (
    is  => 'rw',
    isa => 'Warg::IRC::Client',
    required => 1,
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use AnyEvent;
use Coro;
use String::Random qw(random_regex);
use Carp;

sub say {
    my ($self, $message, $args) = @_;
    croak unless $args->{channel};

    $self->client->notice($args->{channel}, $message);
}

sub ask {
    my ($self, $prompt, $args) = @_;
    croak unless $args->{channel};

    my $session = random_regex('\w{4}');
    $self->client->notice($args->{channel}, qq<[$session] $prompt? (reply as '$session=blah')>);

    # TODO ここもっと簡単に登録したい
    my $cb = rouse_cb;
    my $guard = $self->client->reg_cb(
        publicmsg => sub {
            my ($con, $channel, $msg) = @_;

            return unless $channel eq $args->{channel};
            my $text = $msg->{params}->[1];
            return unless $text =~ /^\s*$session=(.+)$/;

            $cb->($1);
        }
    );

    my $reply = rouse_wait $cb;
    return $reply;
}

sub interact {
    my ($self, $cb) = @_;

    $self->client->reg_cb(
        publicmsg => sub {
            my ($con, $channel, $msg) = @_;

            my $text = $msg->{params}->[1];
            $cb->($text, { channel => $channel });
        }
    );
    $self->client->start;

    AE::cv->wait;
}

1;
