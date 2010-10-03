package Warg::CLI;
use Any::Moose;

# is
# - warg cli
# has
# - irc client
# - downloader manager
# - logger
# does
# - setup components
# - run everything

use Warg::IRC::Client;
use Warg::Manager;
use AnyEvent;
use Coro::Timer;
use Log::Handler;

with any_moose('X::Getopt::Strict');

# --server localhost:6667
has server => (
    is  => 'rw',
    isa => 'Str',
    metaclass => 'Getopt',
    required  => 1,
    documentation => 'IRC server to connect (host:port)',
);

# --debug | -d
has debug => (
    is  => 'rw',
    isa => 'Bool',
    default     => 0,
    metaclass   => 'Getopt',
    cmd_aliases => 'd',
);

# --downloader-dir | -D ./downloader
has downloader_dir => (
    is  => 'rw',
    isa => 'Str',
    default     => './downloader',
    metaclass   => 'Getopt',
    cmd_flag    => 'downloader-dir',
    cmd_aliases => 'D',
    documentation => 'Downloader scripts directory',
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

has irc => (
    is  => 'rw',
    isa => 'Warg::IRC::Client',
    lazy_build => 1,
);

sub _build_irc {
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

has manager => (
    is  => 'rw',
    isa => 'Warg::Manager',
    lazy_build => 1,
);

sub _build_manager {
    my $self = shift;
    return Warg::Manager->new(
        client         => $self->irc,
        downloader_dir => $self->downloader_dir,
    );
}

no Any::Moose;

sub run {
    my $self = shift;
    $self->irc->start;
    $self->manager->initialize;
    $self->cv->wait;
}

sub cv {
    return AE::cv;
}

sub sleep {
    my ($self, $n) = @_;
    Coro::Timer::sleep $n;
}

1;
