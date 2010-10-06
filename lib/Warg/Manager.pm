package Warg::Manager;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

with 'Warg::Role::Log';

# is
# - downloder manager
# has
# - irc client
# - downloader metadata & global config
# does
# - check human input for new download
# - produce downloader session

has client => (
    is  => 'ro',
    isa => 'Warg::IRC::Client',
);

has downloader_dir => (
    is  => 'rw',
    isa => 'Path::Class::Dir',
    coerce   => 1,
    required => 1,
);

has script_metadata => (
    is  => 'rw',
    isa => 'HashRef[Warg::Downloader::Metadata]',
    default => sub { +{} },
);

has mech => (
    is  => 'rw',
    isa => 'Warg::Mech',
    lazy_build => 1,
);

sub _build_mech {
    my $self = shift;
    return Warg::Mech->new(logger => $self->logger);
}

no Any::Moose;

use Warg::Mech;
use Warg::Downloader::Metadata;

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $self = shift;

    foreach (grep { $_->basename =~ /\.pl$/ }  $self->downloader_dir->children) {
        $self->log(info => "loading metadata of $_");
        $self->script_metadata->{$_} = Warg::Downloader::Metadata->new(script => $_);
    }
}

sub produce_downloader_from_url {
    my ($self, $url, %args) = @_;

    $self->mech->get($url);

    foreach (sort keys %{ $self->script_metadata }) {
        my $meta = $self->script_metadata->{$_} or next;
        $meta->handles_res($self->mech->response) or next;

        return $meta->new_downloader(
            $self->client ? (
                interface => Warg::Downloader::Interface::IRC->new(
                    client  => $self->client,
                    channel => $args{channel},
                ),
            ) : (),
            mech => $self->mech->clone,
            %args,
        );
    }
}

1;
