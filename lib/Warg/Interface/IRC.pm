package Warg::Interface::IRC;
use Any::Moose;

with 'Warg::Role::Interface';
with 'Warg::Role::Log';

# --server localhost:6667
has server => (
    is  => 'rw',
    isa => 'Str',
    metaclass => 'Getopt',
    required  => 1,
    documentation => 'IRC server to connect (host:port)',
);

# --nick warg
has nick => (
    is  => 'rw',
    isa => 'Str',
    metaclass => 'Getopt',
    documentation => 'IRC nick',
);

# --password xyz
has password => (
    is  => 'rw',
    isa => 'Str',
    metaclass => 'Getopt',
    documentation => 'IRC server password',
);

# --channel #hoge --channel #fuga
has channels => (
    is  => 'rw',
    isa => 'ArrayRef[Str]',
    metaclass => 'Getopt',
    cmd_flag  => 'channel',
    documentation => 'Specify channel(s) to work in',
);

has irc_client => (
    is  => 'rw',
    isa => 'Warg::IRC::Client',
    lazy_build => 1,
);

sub _build_irc_client {
    my $self = shift;

    my ($host, $port) = split /:/, $self->server;
    my %args = (
        host   => $host,
        port   => $port,
        logger => $self->logger,
    );
    for (qw(nick password)) {
        $args{$_} = $self->{$_} if $self->{$_};
    }

    return Warg::IRC::Client->new(%args);
}

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use Warg::IRC::Client;

use AnyEvent;
use Coro;
use String::Random qw(random_regex);
use Carp;

sub say {
    my ($self, $message, $args) = @_;
    croak unless $args->{channel};

    $self->irc_client->notice($args->{channel}, $message);
}

sub ask {
    my ($self, $prompt, $args) = @_;
    croak unless $args->{channel};

    my $session = random_regex('\w{4}');
    $self->irc_client->notice($args->{channel}, qq<[$session] $prompt? (reply as '$session=blah')>);

    # TODO ここもっと簡単に登録したい
    my $cb = rouse_cb;
    my $guard = $self->irc_client->reg_cb(
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

    $self->irc_client->reg_cb(
        publicmsg => sub {
            my ($con, $channel, $msg) = @_;

            if ($self->channel_is_to_work_in($channel)) {
                my $text = $msg->{params}->[1];
                $cb->($text, { channel => $channel });
            }
        }
    );
    $self->irc_client->start;

    AE::cv->wait;
}

sub channel_is_to_work_in {
    my ($self, $channel) = @_;

    return 1 unless $self->channels;

    foreach (@{ $self->channels }) {
        return 1 if $_ eq $channel;
    }

    return 0;
}

1;
