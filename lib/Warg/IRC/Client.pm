package Warg::IRC::Client;
use Any::Moose;

use AnyEvent::IRC::Client;
use AnyEvent::IRC::Util qw(mk_msg rfc_code_to_name);

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
);

has password => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

has port => (
    is  => 'rw',
    isa => 'Int',
    required => 1,
);

has host => (
    is  => 'rw',
    isa => 'Str',
    required => 1,
);

has logger => (
    is  => 'rw',
    isa => 'Maybe[Log::Handler]',
);

no Any::Moose;

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

sub log {
    my ($self, $level, @args) = @_;
    if ($self->logger) {
        $self->logger->log($level, @args);
    }
}

# $irc->notice($channel, $message)
sub notice {
    my $self = shift;
    $self->client->send_srv(NOTICE => @_);
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
    $self->log(error => rfc_code_to_nick($code), $message);
}

1;
