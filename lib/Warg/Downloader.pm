package Warg::Downloader;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

# is
# - downloader, session
# has
# - coderef to execute
# - interface
# - mech
# does
# - download file
# - interact with human via interface

with 'Warg::Role::Log';

has code => (
    is  => 'ro',
    isa => 'CodeRef',
    required => 1
);

our $id = 0;

has id => (
    is  => 'rw',
    isa => 'Int',
    default => sub { ++$id },
);

has mech => (
    is  => 'rw',
    isa => 'Warg::Mech',
    default => sub {
        return Warg::Mech->new;
    },
);

has interface => (
    is => 'rw',
    default => sub {
        require Warg::Interface::Console;
        return  Warg::Interface::Console->new;
    },
);

has args => (
    is  => 'rw',
    isa => 'Maybe[HashRef]',
);

has download_dir => (
    is  => 'rw',
    isa => 'Path::Class::Dir',
    coerce  => 1,
    default => './downloads',
);

has metadata => (
    is  => 'rw',
    isa => 'Warg::Downloader::Metadata',
);

has started_at => (
    is  => 'ro',
    isa => 'Int',
    default => sub { time },
);

sub elapsed { time - $_[0]->started_at }

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use Warg::Mech;

use AnyEvent;
use Coro;
use Coro::LWP;
use Coro::AnyEvent;
use Coro::Timer;
use Guard;
use Cwd qw(getcwd);
use Carp;
use File::Util qw(escape_filename);

sub metadata_class {
    my $class = shift;

    require Warg::Downloader::Metadata;
    return 'Warg::Downloader::Metadata';
}

sub from_script {
    my ($class, $script, %args) = @_;
    my $meta = $class->metadata_class->new(script => $script);
    return $meta->new_downloader(%args);
}

sub work_sync {
    my ($self, $url) = @_;

    croak 'missing url' unless $url;

    my $ret = eval { $self->code->($self, $url) };
    if (!defined $ret && $@) {
        $self->log(error => $@);
    }
    return $ret;
}

sub work {
    my ($self, $url) = @_;

    async {
        $self->work_sync($url);
    };
}

sub name {
    my $self = shift;
    return sprintf "%s[%d]", $self->metadata->name, $self->id;
}

sub log_name { shift->name };

sub say {
    my ($self, @args) = @_;
    $self->log(notice => @args);
    $self->interface->say($self->name . " @args", $self->args ? $self->args : ());
}

sub ask {
    my ($self, $prompt) = @_;
    return $self->interface->ask($self->name . " $prompt", $self->args ? $self->args : ());
}

sub sleep {
    my ($self, $seconds) = @_;
    $self->say("sleep for $seconds seconds");
    Coro::Timer::sleep $seconds;
}

sub prepare_request {
    my ($self, $req) = @_;
    $self->log(debug => $req->method, $req->uri);
}

sub chdir_to_download_dir {
    my $self = shift;

    my $cwd = getcwd;

    $self->download_dir->mkpath;
    chdir $self->download_dir;

    return guard { chdir $cwd };
}

sub download {
    my ($self, $url, $option) = @_;

    $option ||= {};

    my $guard = $self->chdir_to_download_dir;

    $self->say("start downloading <$url>");

    my ($filename, $fh);
    my $res = $self->mech->get($url, ':content_cb' => sub {
        my ($data, $res) = @_;
        unless (defined $fh) {
            $filename = $res->filename || $url;
            $filename = $option->{prefix} . $filename if defined $option->{prefix};
            $filename = escape_filename $filename;

            open $fh, '>', $filename or die $!;
            $self->log(info => "filename: $filename");
        }
        print $fh $data;
    });
    close $fh if defined $fh;

    $self->say("downloaded $filename");
}

1;
