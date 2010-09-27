package Warg::Downloader::Metadata;
use Any::Moose;

has metadata => (
    is  => 'rw',
    isa => 'HashRef',
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

sub from_script;
sub handles_url;

1;
