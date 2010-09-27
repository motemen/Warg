package Warg::CLI;
use Any::Moose;

use Warg::IRC::Client;
use AnyEvent;
use Log::Handler;

with any_moose('X::Getopt::Strict');

has server => (
    is  => 'rw',
    isa => 'Str',
    metaclass => 'Getopt',
    required  => 1,
);

has debug => (
    is  => 'rw',
    isa => 'Bool',
    metaclass => 'Getopt',
    default   => 0,
);

has name => (
    is  => 'rw',
    isa => 'Str',
    metaclass => 'Getopt',
);

has client => (
    is  => 'rw',
    isa => 'Warg::IRC::Client',
    lazy_build => 1,
);

sub _build_client {
    my $self = shift;

    my ($host, $port) = split /:/, $self->server;
    my %args = (
        host   => $host,
        port   => $port,
        logger => $self->logger,
    );
    $args{name} = $self->name if $self->name;

    return Warg::IRC::Client->new(%args);
}

has logger => (
    is  => 'rw',
    isa => 'Log::Handler',
    lazy_build => 1,
);

sub _build_logger {
    my $self = shift;
    my $logger = Log::Handler->new;
    $logger->add(
        screen => {
            maxlevel       => $self->debug ? 'debug' : 'info',
            message_layout => '%T %p [%L] %m',
            timeformat     => "%Y-%m-%d %H:%M:%S",
        }
    );
    return $logger;
}

no Any::Moose;

sub run {
    my $self = shift;
    $self->client->start;
    $self->cv->wait;
}

sub cv {
    return AE::cv;
}

1;
