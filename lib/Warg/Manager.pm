package Warg::Manager;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

has client => (
    is  => 'ro',
    isa => 'Warg::IRC::Client',
    required => 1,
);

has script_dir => (
    is  => 'rw',
    isa => 'Path::Class::Dir',
    coerce   => 1,
    required => 1,
);

has scripts => (
    is  => 'rw',
    isa => 'ArrayRef',
    auto_deref => 1,
    lazy_build => 1,
);

has script_metadata => (
    is  => 'rw',
    isa => 'HashRef[Warg::Downloader::Metadata]',
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

sub produce_downloader_from_url {
    my ($self, $url) = @_;

    foreach ($self->scripts) {
        my $meta = $self->script_metadata->{$_} or next;
        if ($meta->handles_url($url)) {
            return $self->produce_downloder(
                script => $_,
                url    => $url,
            );
        }
    }
}

1;
