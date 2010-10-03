package Warg::Downloader::Interface::IRC;
use Any::Moose;
use Coro;
use String::Random qw(random_regex);

has client => (
    is  => 'rw',
    isa => 'Warg::IRC::Client',
    required => 1,
);

has channel => (
    is  => 'rw',
    isa => 'Str',
);

sub _notice {
    my $self = shift;
    $self->client->notice($self->channel, @_);
}

sub say {
    my ($self, $message) = @_;
    $self->_notice($message);
}

sub ask {
    my ($self, $prompt) = @_;

    my $session = random_regex('\w{4}');
    $self->_notice(qq<[$session] $prompt (reply as 'warg: $session=blah)>);

    # TODO ここもっと簡単に登録したい
    my $cb = rouse_cb;
    my $guard = $self->client->reg_cb(
        publicmsg => sub {
            my ($con, $channel, $msg) = @_;

            my $text = $msg->{params}->[1];
            return unless $text =~ /^warg:\s*$session=(.+)$/;

            $cb->($1);
        }
    );

    my $reply = rouse_wait $cb;
    return $reply;
}

1;
