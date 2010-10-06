package Warg::Manager;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

# XXX なぜかここに置くとうまくいく…
use Warg::Downloader::Interface::Console;

with 'Warg::Role::Log';

# is
# - downloder manager
# has
# - interface to human
# - downloader metadata & global config
# does
# - check human input for new download
# - produce downloader session

has interface => (
    is  => 'rw',
    isa => 'Warg::Role::Interface',
    default => sub {
        # require Warg::Downloader::Interface::Console; # XXX なぜか require だとうまくいかない…
        return  Warg::Downloader::Interface::Console->new;
    },
);

has downloader_dir => (
    is  => 'rw',
    isa => 'Path::Class::Dir',
    coerce   => 1,
    required => 1,
    default  => './downloader',
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
use Coro;
use Regexp::Common qw(URI);

our $RE_HTTP = $RE{URI}{HTTP}{ -scheme => 'https?' };

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
            interface => $self->interface,
            mech => $self->mech->clone,
            %args,
        );
    }
}

sub handle_input {
    my ($self, $input, $args) = @_;
    foreach my $url ($input =~ /$RE_HTTP/go) {
        if (my $downloder = $self->produce_downloader_from_url($url, args => $args)) {
            $downloder->work($url);
        } else {
            $self->log(notice => "Cannot handle $url");
        }
    }
}

sub start_interactive {
    my $self = shift;
    $self->interface->interact(sub { $self->handle_input(@_) });
}

1;
