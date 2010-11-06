package Warg::Role::Log;
use Any::Moose '::Role';
use Log::Handler;

our $DefaultLogLevel ||= 'notice';

has logger => (
    is  => 'rw',
    isa => 'Log::Handler',
    lazy_build => 1,
);

has log_level => (
    is  => 'rw',
    isa => 'Str',
    default => sub { $DefaultLogLevel },
    trigger => \&_set_logger_level,
);

sub _build_logger {
    my $self = shift;
    return Log::Handler->new(
        screen => {
            alias          => 'screen',
            maxlevel       => $self->log_level,
            message_layout => '%T [%L] %m',
            timeformat     => "%Y-%m-%d %H:%M:%S",
        },
    );
}

sub _set_logger_level {
    my $self = shift;
    $self->logger->set_level(screen => { maxlevel => $self->log_level });
}

sub log {
    my ($self, $level, @args) = @_;
    $self->logger->$level($self->log_name, @args);
}

sub log_name {
    my $self  = shift;
    my $class = ref $self;
    $class =~ s/^Warg:://;
    return $class;
}

1;
