package Warg::Downloader;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

has script => (
    is  => 'ro',
    isa => 'Path::Class::File',
    coerce   => 1,
    required => 1,
);

has client => (
    is  => 'ro',
    isa => 'Warg::IRC::Client',
    required => 1,
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

sub work;

1;
