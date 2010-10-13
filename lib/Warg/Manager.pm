package Warg::Manager;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

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
    is => 'rw',
);

has scripts_dir => (
    is  => 'rw',
    isa => 'Path::Class::Dir',
    coerce   => 1,
    required => 1,
    default  => './scripts',
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

has download_dir => (
    is  => 'rw',
    isa => 'Path::Class::Dir',
    coerce   => 1,
    required => 1,
    default  => './downloads',
);

sub _build_mech {
    my $self = shift;
    return Warg::Mech->new(logger => $self->logger);
}

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use Warg::Mech;
use Warg::Downloader::Metadata;
use Coro;
use Regexp::Common qw(URI);
use UNIVERSAL::require;

our $RE_HTTP = $RE{URI}{HTTP}{ -scheme => 'https?' };

sub BUILD {
    my $self = shift;
    $self->load_script_metadata;
}

sub load_script_metadata {
    my $self = shift;
    foreach (grep { $_->basename =~ /\.pl$/ }  $self->scripts_dir->children) {
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

        $self->log(notice => "$meta->{script} is going to handle $url");

        return $meta->new_downloader(
            mech         => $self->mech->clone,
            download_dir => $self->download_dir,
            logger       => $self->logger,
            $self->interface ? ( interface => $self->interface ) : (),
            %args,
        );
    }
}

sub handle_input {
    my ($self, $input, $args) = @_;

    if ($input eq 'warg.reload') {
        if (Module::Refresh->require) {
            Module::Refresh->refresh;
        }
        $self->script_metadata({});
        $self->load_script_metadata;
    }

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

package Warg::Manager::Commands;

sub reload {
}

sub jobs {
}

1;
