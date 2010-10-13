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

has jobs => (
    is  => 'rw',
    isa => 'HashRef[Warg::Downloader]',
    default => sub { +{} },
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use Warg::Mech;
use Warg::Downloader::Metadata;
use Coro;
use Regexp::Common qw(URI);

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

    if ($input =~ /^warg\.(\w+)$/) {
        if (my $code = Warg::Manager::Commands->can($1)) {
            $self->$code;
        }
    }

    foreach my $url ($input =~ /$RE_HTTP/go) {
        if (my $downloader = $self->produce_downloader_from_url($url, args => $args)) {
            $self->jobs->{ $downloader->id } = $downloader;
            $downloader->work($url, sub { delete $self->jobs->{ $downloader->id } });
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
use UNIVERSAL::require;

sub reload {
    my $self = shift;

    if (Module::Refresh->require) {
        Module::Refresh->refresh;
    } else {
        $self->log(error => "Could not require Module::Refresh: $@");
    }

    $self->script_metadata({});
    $self->load_script_metadata;
}

sub jobs {
    my $self = shift;

    while (my ($id, $job) = each %{ $self->jobs }) {
        $self->interface->say(sprintf '%s: %s', $id, $job->name);
    }
}

1;
