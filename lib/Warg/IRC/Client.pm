package Warg::IRC::Client;
use Any::Moose;

with any_moose('X::Getopt::Strict');
with 'Warg::Role::Log';

has client => (
    is  => 'rw',
    isa => 'AnyEvent::IRC::Client',
    lazy_build => 1,
    handles => [ 'reg_cb' ],
);

sub _build_client {
    my $self = shift;
    return AnyEvent::IRC::Client->new;
}

has nick => (
    is  => 'rw',
    isa => 'Str',
    default => 'warg',
    metaclass => 'Getopt',
);

has password => (
    is  => 'rw',
    isa => 'Maybe[Str]',
    metaclass => 'Getopt',
);

has port => (
    is  => 'rw',
    isa => 'Int',
    default => 6667,
    required => 1,
    metaclass => 'Getopt',
);

has host => (
    is  => 'rw',
    isa => 'Str',
    required => 1,
    metaclass => 'Getopt',
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use AnyEvent::IRC::Client;
use AnyEvent::IRC::Util qw(mk_msg rfc_code_to_name);

sub connect_info {
    my $self = shift;

    my %info = (
        nick => $self->nick,
        name => __PACKAGE__,
    );
    $info{password} = $self->password if $self->password;

    return \%info;
}

sub start {
    my $self = shift;
    $self->log(notice => 'starting');
    $self->setup_callbacks;
    $self->log(notice => "connecting to $self->{host}:$self->{port}");
    $self->client->connect($self->host, $self->port, $self->connect_info);
}

sub setup_callbacks {
    my $self = shift;
    my $class = ref $self;
    foreach (keys %Warg::IRC::Client::) {
        my ($ev) = /^on_(\w+)$/   or next;
        my $code = $self->can($_) or next;
        $self->client->reg_cb($ev => sub { $self->$code(@_) });
    }
}

# $irc->notice($channel, $message)
sub notice {
    my ($self, $channel, @args) = @_;
    my $message = "@args";
    utf8::encode $message;
    $self->client->send_srv(NOTICE => $channel, $message);
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

sub on_debug_send {
    my ($self, $con, $command, @params) = @_;
    $self->log(debug => ">>> $command @params");
}

sub on_debug_recv {
    my ($self, $con, $ircmsg) = @_;
    my $line = mk_msg $ircmsg->{prefix}, $ircmsg->{command}, @{$ircmsg->{params}};
    $self->log(debug => "<<< $line");
}

sub on_error {
    my ($self, $con, $code, $message, $ircmsg) = @_;
    $self->log(error => rfc_code_to_name($code), $message);
}

1;
