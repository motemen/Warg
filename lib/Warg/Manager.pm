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

no Any::Moose;

use Warg::Downloader::Metadata;
use LWP::Simple qw($ua); # XXX mech?

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

    # mech->get にして、場合によっては downloder が最初のレスポンスを再利用する
    # という風にするのがいいかも

    my $res = $ua->head($url);

    foreach (sort keys %{ $self->script_metadata }) {
        my $meta = $self->script_metadata->{$_} or next;
        $meta->handles_res($res) or next;

        return $meta->new_downloader(
            $self->client ? (
                interface => Warg::Downloader::Interface::IRC->new(
                    client  => $self->client,
                    channel => $args{channel},
                ),
            ) : (),
            %args,
        );
    }
}

1;
