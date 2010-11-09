package Warg::Manager;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

with 'Warg::Role::Log';

# is
# - downloader manager
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

has control_listen => (
    is  => 'rw',
    isa => 'Str',
);

has control_socket_guard => (
    is  => 'rw',
    isa => 'Guard',
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use AnyEvent::Socket;
use Warg::Mech;
use Warg::Downloader::Metadata;
use Coro;
use Coro::Timer;
use Coro::Handle;
use Regexp::Common qw(URI);

our $RE_HTTP = $RE{URI}{HTTP}{ -scheme => 'https?' };

sub BUILD {
    my $self = shift;
    $self->load_script_metadata;
    $self->setup_control_socket;
}

sub load_script_metadata {
    my $self = shift;
    foreach (grep { $_->basename =~ /\.pl$/ }  $self->scripts_dir->children) {
        $self->log(info => "loading metadata of $_");
        $self->script_metadata->{$_} = Warg::Downloader::Metadata->new(script => $_);
    }
}

sub setup_control_socket {
    my $self = shift;
    my $listen = $self->control_listen or return;
    my ($host, $port) = $listen =~ /^(.*):(\d+)$/ ? ($1, $2) : ('unix/', $listen);
    $self->{control_socket_guard} = tcp_server $host, $port, unblock_sub {
        my ($fh, $host, $port) = @_;
        $fh = unblock $fh;
        while (my $input = $fh->readline) {
            chomp $input;
            
            my ($command, @args) = split /\s+/, $input or next;
            if (my $control = Warg::Manager::Control->can($command)) {
                my $res = eval { $self->$control(@args) } || $@;
                $res .= "\n" unless $res =~ /\n$/;
                utf8::encode $res if utf8::is_utf8 $res;
                $fh->print($res) if defined $res;
            }
        }
    };
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

sub work_for_url {
    my ($self, $url, $args) = @_;

    if (my $downloader = $self->produce_downloader_from_url($url, args => $args)) {
        $self->jobs->{ $downloader->id } = $downloader;
        $downloader->work($url, sub { delete $self->jobs->{ $downloader->id } });
    } else {
        $self->log(notice => "Cannot handle $url");
    }
}

sub cancel {
    my ($self, $id) = @_;
    my $downloader = delete $self->jobs->{$id} or return undef;
    $downloader->cancel;
    return $downloader;
}

sub handle_input {
    my ($self, $input, $args) = @_;

    if ($input =~ /^warg:(\w+)$/) {
        if (my $code = Warg::Manager::Commands->can($1)) {
            $self->$code($input, $args);
        }
    }

    foreach my $url ($input =~ /$RE_HTTP/go) {
        $self->work_for_url($url, $args);
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

    # TODO cwd
    $self->script_metadata({});
    $self->load_script_metadata;
}

sub jobs {
    my ($self, undef, $args) = @_;

    my @status;
    while (my ($id, $downloader) = each %{ $self->jobs }) {
        push @status, $downloader->status_string;
    }
    $self->interface->say(join("\n", @status), $args);
}

package Warg::Manager::Control;

sub work {
    my ($self, $url) = @_;
    $self->work_for_url($url) if $url;
}

sub jobs {
    my $self = shift;
    return join("\n", map $_->serialize_as_json, values %{ $self->jobs }) . "\n";
}

sub reload {
    require Module::Refresh;
    Module::Refresh->refresh;
    return 'reloaded'
}

sub cancel {
    my ($self, $id) = @_;
    my $downloader = $self->cancel($id);

    if ($downloader) {
        return $downloader->serialize_as_json;
    } else {
        return 'job not found';
    }
}

1;
