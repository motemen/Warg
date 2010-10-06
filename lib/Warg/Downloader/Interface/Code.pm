package Warg::Downloader::Interface::Code;
use Any::Moose;

with 'Warg::Role::Interface';

has say_handler => (
    is  => 'rw',
    isa => 'CodeRef',
    init_arg => 'say',
    required => 1,
);

has ask_handler => (
    is  => 'rw',
    isa => 'CodeRef',
    init_arg => 'ask',
    required => 1,
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

sub say {
    my $self = shift;
    $self->say_handler->($self, @_);
}

sub ask {
    my $self = shift;
    $self->ask_handler->($self, @_);
}

sub interact {
}

1;
