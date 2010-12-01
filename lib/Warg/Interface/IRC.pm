package Warg::Interface::IRC;
use Any::Moose;

extends 'Warg::Interface';

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
    default => 'warg',
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
    isa => 'AnyEvent::IRC::Client',
    default => sub { AnyEvent::IRC::Client->new },
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use AnyEvent;
use AnyEvent::IRC::Client;
use AnyEvent::IRC::Util qw(mk_msg rfc_code_to_name);
use Coro;
use Coro::Timer;
use String::Random qw(random_regex);
use Carp;

sub say {
    my ($self, $message, $args) = @_;
    croak 'no channel specified' unless $args->{channel};

    my ($msg, @msgs) = split /\n/, $message;

    $self->notice($args->{channel}, $msg);

    foreach (@msgs) {
        Coro::Timer::sleep 1;
        $self->notice($args->{channel}, $_);
    }
}

sub ask {
    my ($self, $prompt, $args) = @_;
    croak 'no channel specified' unless $args->{channel};

    my $session = random_regex('\w{4}');
    $self->notice($args->{channel}, qq<[$session] $prompt (reply as '$session=blah')>);

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

    $self->setup_callbacks;

    my ($host, $port) = split /:/, $self->server;
    $self->log(notice => "connecting to $host:$port");
    $self->irc_client->connect($host, $port, $self->connect_info);

    AE::cv->wait;
}

sub channel_is_to_work_in {
    my ($self, $channel) = @_;

    return 1 unless $self->channels;

    foreach (@{ $self->channels }) {
        return 1 if uc $_ eq uc $channel;
    }

    return 0;
}

sub setup_callbacks {
    my $self = shift;
    my $class = ref $self;
    foreach (keys %Warg::Interface::IRC::) {
        my ($ev) = /^on_(\w+)$/   or next;
        my $code = $self->can($_) or next;
        $self->irc_client->reg_cb($ev => sub { $self->$code(@_) });
    }
}

sub notice {
    my ($self, $channel, @args) = @_;
    my $message = "@args";
    utf8::encode $message;
    $self->irc_client->send_srv(NOTICE => $channel, $message);
}

sub connect_info {
    my $self = shift;

    return +{
        nick => $self->nick,
        name => __PACKAGE__,
        $self->password ? ( password => $self->password ) : (),
    };
}

### Handlers

sub on_connect {
    my ($self, $con, $err) = @_;
    if (defined $err) {
        $self->log(error => "connect: $err");
    } else {
        $self->log(notice => 'connected');
    }
}

sub on_registered {
    my ($self, $con) = @_;
    foreach (@{ $self->channels }) {
        $con->send_srv(JOIN => $_);
    }
}

sub on_debug_send {
    my ($self, $con, $command, @params) = @_;
    return if $command eq 'PONG';
    $self->log(debug => ">>> $command @params");
}

sub on_debug_recv {
    my ($self, $con, $ircmsg) = @_;
    return if $ircmsg->{command} eq 'PING';
    my $line = mk_msg $ircmsg->{prefix}, $ircmsg->{command}, @{$ircmsg->{params}};
    $self->log(debug => "<<< $line");
}

sub on_error {
    my ($self, $con, $code, $message, $ircmsg) = @_;
    $self->log(error => rfc_code_to_name($code), $message);
}

1;
